#!/bin/bash
set -euo pipefail

INSTALL_PATH="/usr/local/share/antigravity"
INSTALLER_URL="https://antigravity.google/cli/install.sh"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the antigravity installer" >&2
	exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

staged_bin="${staging}/bin"

curl -fsSL "${INSTALLER_URL}" -o "${staging}/install.sh"

env HOME="${staging}" bash "${staging}/install.sh" --dir "${staged_bin}"

binary="${staged_bin}/agy"

if [ ! -x "${binary}" ]; then
	echo "the antigravity installer left no runnable binary at ${binary}" >&2
	exit 1
fi

install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/agy"

ln -sfn "${INSTALL_PATH}/bin/agy" /usr/local/bin/agy

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
