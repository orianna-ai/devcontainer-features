#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
BROWSERS_PATH="/usr/local/share/ms-playwright"

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

npm_root="$(npm root -g)"
owner="$(stat -c '%u:%g' "${npm_root}")"

npm install --global "@playwright/cli@${VERSION}"

playwright_core="$(find "${npm_root}" -maxdepth 6 -path '*/playwright-core/cli.js' -print -quit)"

if [ -z "${playwright_core}" ]; then
	echo "playwright-core was not found under ${npm_root}" >&2
	exit 1
fi

apt-get update -y

node "${playwright_core}" install-deps chromium
node "${playwright_core}" install chromium

rm -rf /var/lib/apt/lists/*
npm cache clean --force

chown -R "${owner}" "${npm_root}" "$(npm prefix -g)/bin" "${BROWSERS_PATH}"
chmod -R a+rX "${BROWSERS_PATH}"
