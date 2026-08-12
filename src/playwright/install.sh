#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
BROWSERS_PATH="/usr/local/share/ms-playwright"
INSTALL_PATH="/usr/local/share/playwright-cli"

export DEBIAN_FRONTEND=noninteractive
export PLAYWRIGHT_BROWSERS_PATH="${BROWSERS_PATH}"

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get was not found; this feature only supports debian and ubuntu base images" >&2
	exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
	export NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"

	# shellcheck source=/dev/null
	[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
fi

if ! command -v npm >/dev/null 2>&1; then
	echo "npm was not found; this feature has to install after the node feature" >&2
	exit 1
fi

owner="$(stat -c '%u:%g' "$(npm root -g)")"

npm install --global --prefix "${INSTALL_PATH}" "@playwright/cli@${VERSION}"

node_modules="${INSTALL_PATH}/lib/node_modules"
playwright_core="$(find "${node_modules}" -maxdepth 6 -path '*/playwright-core/cli.js' -print -quit)"

if [ -z "${playwright_core}" ]; then
	echo "playwright-core was not found under ${node_modules}" >&2
	exit 1
fi

apt-get update -y

node "${playwright_core}" install-deps chromium
node "${playwright_core}" install chromium

rm -rf /var/lib/apt/lists/*
npm cache clean --force

ln -sfn "${INSTALL_PATH}/bin/playwright-cli" /usr/local/bin/playwright-cli

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

chown -R "${owner}" "${BROWSERS_PATH}"
chmod -R a+rX "${BROWSERS_PATH}"
