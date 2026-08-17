## Requirements

None beyond a Debian or Ubuntu base image with `curl`. The CLI is a single static binary, so —
unlike the playwright and typescript-language-server features — this one needs no node feature
alongside it and installs nothing into a node version's global root.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/grok:1": {}
}
```

## Where it installs

The binary is copied to `/usr/local/share/grok/bin/grok` and symlinked to `/usr/local/bin/grok`,
the same shared-prefix shape the other features use: one root-owned copy, readable and executable
by every user, writable by none of them.

Upstream's installer is run to fetch the binary rather than reimplementing its platform detection
and channel lookup, but it is not left to place the result. It downloads into a hardcoded
`$HOME/.grok/downloads` and makes `$HOME/.grok/bin/grok` a symlink pointing at that download, so an
install run as root during a build puts the real file under `/root` — reachable while building,
unreadable to the remote user afterwards. Setting `GROK_BIN_DIR` alone does not fix this: it moves
the symlink and leaves the binary behind it in root's home. The feature instead stages a `HOME`,
lets the installer lay out both halves inside it, copies the resolved binary into the shared
prefix, and deletes the staging directory.

## Authentication

Nothing is authenticated at build time, and that holds even when the build environment says
otherwise. A feature inherits the environment it is installed into, so an exported
`GROK_DEPLOYMENT_KEY` would otherwise make the installer authenticate and POST that key as a bearer
token to `${GROK_PROXY_URL:-https://cli-chat-proxy.grok.com/v1}/deployment/config` — a credential
sent to whatever endpoint an inherited `GROK_PROXY_URL` named. The installer is therefore run with
`GROK_DEPLOYMENT_KEY`, `GROK_PROXY_URL`, `GROK_CHANNEL`, and `GROK_BIN_DIR` cleared, over a staged
`HOME` holding no `.grok/auth.json`, leaving it only its unauthenticated path to the public stable
build.

Nothing is read, so nothing can be baked into an image layer, and the CLI still reads whatever
credentials it is given at run time.

The upstream installer also honors `GROK_CHANNEL` for alpha and enterprise builds. This feature
does not expose it: the enterprise channel needs a deployment key a feature has no way to carry,
and pinning `version` covers the reason to reach for a non-stable channel in the first place.

## Version pinning

`version` accepts an exact `X.Y.Z` (the installer rejects anything else), which freezes the CLI
into the image digest. The default, `latest`, resolves the channel's newest build at *image build*
time — so it is still fixed for the life of the image, and moves only when the image is rebuilt.
That is the point of installing it here rather than at container start: every container from a
given image runs a known version instead of whatever was newest when it happened to boot.

## The `agent` alias

Upstream's installer also links the binary as `agent`. This feature installs only `grok`. The
generic name is a poor thing to claim in a shared image, and nothing that consumes the CLI needs
it — invoke `grok` directly.
