#!/bin/bash
set -euo pipefail

INSTALL_PATH="/usr/local/share/antigravity"
MANIFEST_URL="https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the antigravity release" >&2
	exit 1
fi

case "$(uname -m)" in
x86_64 | amd64) arch="amd64" ;;
aarch64 | arm64) arch="arm64" ;;
*)
	echo "unsupported architecture for the antigravity CLI: $(uname -m)" >&2
	exit 1
	;;
esac

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

manifest="$(curl -fsSL "${MANIFEST_URL}/linux_${arch}.json")"

manifest_value() {
	sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"${manifest}" | head -n 1
}

version="$(manifest_value version)"
url="$(manifest_value url)"
sha512="$(manifest_value sha512)"

if [ -z "${url}" ] || [ -z "${sha512}" ]; then
	echo "the antigravity release manifest for linux_${arch} names no url or sha512" >&2
	exit 1
fi

echo "installing antigravity ${version} for linux_${arch}"

curl -fsSL "${url}" -o "${staging}/agy.tar.gz"

echo "${sha512}  ${staging}/agy.tar.gz" | sha512sum -c --quiet -

tar -xzf "${staging}/agy.tar.gz" -C "${staging}" antigravity

binary="${staging}/antigravity"

if [ ! -x "${binary}" ]; then
	echo "the antigravity release archive held no runnable binary" >&2
	exit 1
fi

install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/agy"

ln -sfn "${INSTALL_PATH}/bin/agy" /usr/local/bin/agy

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
