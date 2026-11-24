#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
INSTALL_PATH="/usr/local/share/fleetctl"
RELEASES_URL="https://github.com/fleetdm/fleet/releases"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to download fleetctl" >&2
	exit 1
fi

case "$(uname -m)" in
x86_64 | amd64) arch=amd64 ;;
aarch64 | arm64) arch=arm64 ;;
*)
	echo "fleetctl publishes no linux build for $(uname -m)" >&2
	exit 1
	;;
esac

if [ "${VERSION}" = "latest" ]; then
	latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "${RELEASES_URL}/latest")"
	VERSION="${latest_url##*/fleet-v}"
fi

if [[ ! ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "version must be X.Y.Z or latest, not ${VERSION}" >&2
	exit 1
fi

archive="fleetctl_v${VERSION}_linux_${arch}"
url="${RELEASES_URL}/download/fleet-v${VERSION}/${archive}.tar.gz"

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

curl -fsSL "${url}" -o "${staging}/fleetctl.tar.gz"
tar -xzf "${staging}/fleetctl.tar.gz" -C "${staging}" "${archive}/fleetctl"

install -D -m 0755 "${staging}/${archive}/fleetctl" "${INSTALL_PATH}/bin/fleetctl"
ln -sfn "${INSTALL_PATH}/bin/fleetctl" /usr/local/bin/fleetctl

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
