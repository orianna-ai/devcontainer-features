## Requirements

A Debian or Ubuntu base image with `curl`, `unzip` and `sha256sum`, all of which `common-utils`
provides. The proxy is a Python package, but it does not use the image's Python: a pinned `uv`
release is fetched from PyPI into a staging directory and verified against the digest PyPI
publishes for it, installs a private interpreter and the package into the shared prefix, and
leaves with the staging directory. The image's own Python, if any, is neither read nor written.
It is a large install (a little under 700 MB with the interpreter), which lands as one layer in
whatever image installs it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/litellm:1": {}
}
```

## Where it installs

Everything lands under `/usr/local/share/litellm`: the managed interpreter in `python/`, the
tool environment in `tools/litellm/`, and the launcher in `bin/litellm`, which is symlinked to
`/usr/local/bin/litellm`. The same shared-prefix shape the other features use: one root-owned
copy, readable and executable by every user, writable by none of them.

`uv tool install` would otherwise put the interpreter under `~/.local/share/uv` and the launcher
under `~/.local/bin`, so an install run as root during a build puts both under `/root` —
reachable while building, unreadable to the remote user afterwards. The feature points each at
the shared prefix and stages `HOME` and the download cache, so nothing is left in a home
directory either.

## What it is for

A local translation proxy: Codex speaks only the OpenAI Responses API and Claude Code only the
Anthropic Messages API, and an upstream that serves only Chat Completions (LithosAI, for one) is
reachable from either through `litellm` bridging the wire protocol. The feature installs the
proxy; configuring and starting it, with the upstream's credential, is up to whatever drives
the CLIs.

## Authentication

Nothing is authenticated at build time. The install reaches only PyPI and the managed Python
downloads; it reads no credential from the environment it inherits, so none can be baked into an
image layer. At run time the proxy reads whatever keys its configuration names.

## Version pinning

`version` defaults to a reviewed release rather than to `latest`, and takes an exact `X.Y.Z`,
which freezes the package into the image digest. In March 2026 two litellm releases (1.82.7 and
1.82.8) were briefly replaced on PyPI by a credential stealer; a pinned, known-good default is
what keeps an ordinary image rebuild from picking up the next such release on its own. `latest`
is accepted as an explicit opt-in and resolves the newest release on PyPI at *image build* time —
still fixed for the life of the image, but moving on every rebuild.

`uv` itself is pinned the same way: a fixed version, fetched as the wheel PyPI publishes for the
image's architecture and checked against that wheel's digest before it runs. Bumping it means
updating the version and both digests in `install.sh` together.

`pythonVersion` picks the private interpreter. The package requires Python below 3.15; the
default stays on a release its wheels are well exercised on rather than the newest.
