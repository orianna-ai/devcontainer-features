# Antigravity CLI (antigravity)

Installs the Antigravity CLI from Google.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/antigravity:1": {}
}
```

## Requirements

None beyond a Debian or Ubuntu base image with `curl`. The CLI is a single static binary, so —
unlike the playwright and typescript-language-server features — this one needs no node feature
alongside it and installs nothing into a node version's global root. It is a large binary (a little
over 200 MB), which lands as one layer in whatever image installs it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/antigravity:1": {}
}
```

## Where it installs

The binary is copied to `/usr/local/share/antigravity/bin/agy` and symlinked to
`/usr/local/bin/agy`, the same shared-prefix shape the other features use: one root-owned copy,
readable and executable by every user, writable by none of them.

The feature does not run upstream's `install.sh`. It reads the same per-platform release manifest
that script reads (`manifests/linux_<arch>.json`, with `<arch>` `amd64` or `arm64` from
`uname -m`), downloads the archive the manifest names, checks it against the manifest's sha512, and
extracts the binary straight into the shared prefix. Fetching and executing the installer script
broke arm64 image builds under emulation — bash rejected the downloaded file as binary — and the
script's other side effects (staging through `$HOME/.cache/antigravity`, defaulting to
`$HOME/.local/bin`, and handing off to `agy install` to edit shell profiles) are all things a
shared, root-owned install has to undo anyway. The symlink is what puts the CLI on `PATH`, so
nothing has to be added to a profile.

## Authentication

Nothing is authenticated at build time. The only network calls are to the public release manifest
and the release archive it names; no credential is read from the environment, so none can be baked
into an image layer.

At run time the CLI takes either a cached interactive login or an API key. The key path is the one
a headless container wants: `modelProvider` set to `gemini` in
`~/.gemini/antigravity-cli/settings.json`, with `GEMINI_API_KEY` exported. Both are configured by
whatever drives the CLI, not here.

## Version pinning

The release manifest only names the newest build — upstream publishes no per-version manifest — so
unlike the grok feature there is no `version` option to expose. The version is nonetheless fixed for the life of the image: it resolves at *image build* time and moves only
when the image is rebuilt. That is the point of installing it here rather than at container start.

The CLI also self-updates in the background during normal runs, which would undo that. Installing
it root-owned and read-only to the remote user is what holds a container on the version its image
was built with; a read-only binary still runs normally, and the updater has no writable target to
replace.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
