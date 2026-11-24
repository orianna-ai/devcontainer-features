# fleetctl (fleetctl)

Installs fleetctl, the Fleet CLI.

## Example Usage

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/fleetctl:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Version of fleetctl to install, as X.Y.Z, or latest for the newest release. | string | latest |

## Requirements

None beyond a Debian or Ubuntu base image with `curl` and `tar`, on `amd64` or `arm64`. The CLI is a
single static binary, so this feature needs no node feature alongside it.

```json
"features": {
    "ghcr.io/orianna-ai/devcontainer-features/fleetctl:1": {}
}
```

## Where it installs

The binary is extracted from the release's `fleetctl_v<version>_linux_<arch>.tar.gz` to
`/usr/local/share/fleetctl/bin/fleetctl` and symlinked to `/usr/local/bin/fleetctl`, the same
shared-prefix shape the other features use: one root-owned copy, readable and executable by every
user, writable by none of them.

Upstream also publishes fleetctl on npm, but that package downloads the binary on first run. The
feature takes the release tarball directly, so the binary is in the image.

## Version pinning

`version` accepts an exact `X.Y.Z` release, which freezes the CLI into the image digest. The
default, `latest`, resolves GitHub's newest `fleet-vX.Y.Z` release at *image build* time, so it is
still fixed for the life of the image and moves only when the image is rebuilt.

fleetctl and the Fleet server share a release train, so pin `version` to the server you talk to when
it lags behind upstream.

## Authentication

Nothing is authenticated at build time. Point the CLI at a server with `fleetctl config set
--address` and sign in with `fleetctl login` at run time; both are written to the remote user's
home, not the image.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
