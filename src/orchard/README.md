# Orchard CLI (orchard)

Installs the Orchard CLI from Cirrus Labs.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/orchard:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of the orchard CLI to install, as X.Y.Z, or latest for the newest release. | string | latest |

## Requirements

None beyond a Debian or Ubuntu base image with `curl` and `tar`, on `amd64` or `arm64`. The CLI is a
single static binary, so this feature needs no node feature alongside it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/orchard:1": {}
}
```

## Where it installs

The binary is extracted from the release's `orchard-linux-<arch>.tar.gz` to
`/usr/local/share/orchard/bin/orchard` and symlinked to `/usr/local/bin/orchard`, the same
shared-prefix shape the other features use: one root-owned copy, readable and executable by every
user, writable by none of them.

The only Linux install upstream documents is that tarball (Homebrew covers macOS), so the feature
downloads it directly rather than running an installer script.

## Version pinning

`version` accepts an exact `X.Y.Z` release tag, which freezes the CLI into the image digest. The
default, `latest`, resolves GitHub's newest release at *image build* time, so it is still fixed for
the life of the image and moves only when the image is rebuilt.

Orchard's CLI and controller share a release train, so pin `version` to the controller you talk to
when it lags behind upstream.

## Authentication

Nothing is authenticated at build time. Create a context with `orchard context create` at run time;
it is written to the remote user's home, not the image.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
