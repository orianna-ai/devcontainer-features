#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
INSTALL_PATH="/usr/local/share/orchard"
RELEASES_URL="https://github.com/cirruslabs/orchard/releases"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to download orchard" >&2
	exit 1
fi

case "$(uname -m)" in
x86_64 | amd64) arch=amd64 ;;
aarch64 | arm64) arch=arm64 ;;
*)
	echo "orchard publishes no linux build for $(uname -m)" >&2
	exit 1
	;;
esac

if [ "${VERSION}" = "latest" ]; then
	url="${RELEASES_URL}/latest/download/orchard-linux-${arch}.tar.gz"
elif [[ ${VERSION} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	url="${RELEASES_URL}/download/${VERSION}/orchard-linux-${arch}.tar.gz"
else
	echo "version must be X.Y.Z or latest, not ${VERSION}" >&2
	exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

curl -fsSL "${url}" -o "${staging}/orchard.tar.gz"
tar -xzf "${staging}/orchard.tar.gz" -C "${staging}" orchard

install -D -m 0755 "${staging}/orchard" "${INSTALL_PATH}/bin/orchard"
ln -sfn "${INSTALL_PATH}/bin/orchard" /usr/local/bin/orchard

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
