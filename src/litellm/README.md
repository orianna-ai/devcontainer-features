# LiteLLM proxy (litellm)

Installs the LiteLLM proxy on a private Python runtime, independent of any Python in the image.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/litellm:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| pythonVersion | Version of the private Python runtime that runs the proxy, as X.Y or X.Y.Z. | string | 3.13 |
| version | Version of the litellm package to install, as X.Y.Z, or latest for the newest release on PyPI. | string | latest |

## Requirements

None beyond a Debian or Ubuntu base image with `curl`. The proxy is a Python package, but it
does not use the image's Python: `uv` is fetched into a staging directory, installs a private
interpreter and the package into the shared prefix, and leaves with the staging directory. The
image's own Python, if any, is neither read nor written. It is a large install (a little under
700 MB with the interpreter), which lands as one layer in whatever image installs it.

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

`version` accepts an exact `X.Y.Z`, which freezes the package into the image digest. The default,
`latest`, resolves the newest release on PyPI at *image build* time — so it is still fixed for the
life of the image, and moves only when the image is rebuilt. That is the point of installing it
here rather than at container start: every container from a given image runs a known version.

Pin it. In March 2026 two litellm releases (1.82.7 and 1.82.8) were briefly replaced on PyPI by a
credential stealer; a pinned, known-good version is what keeps a rebuild from picking up the next
such release on its own.

`pythonVersion` picks the private interpreter. The package requires Python below 3.15; the
default stays on a release its wheels are well exercised on rather than the newest.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
