#!/bin/bash
# Bake the Playwright CLI and a Chromium build into the image.
#
# Installing both at run time puts an npm install and a browser download on the critical path of
# every container start. Doing it here trades image size for startup latency.
#
# Browsers land in a system-wide directory rather than Playwright's default "$HOME/.cache", because
# a sandbox may point HOME at a per-pod volume: anything baked into the image's home directory is
# invisible there. PLAYWRIGHT_BROWSERS_PATH (declared in devcontainer-feature.json, so it is baked
# into the image environment) points both the install below and every later run at that directory.
set -euo pipefail

VERSION="${VERSION:-latest}"
BROWSERS_PATH="/usr/local/share/ms-playwright"

export DEBIAN_FRONTEND=noninteractive
export PLAYWRIGHT_BROWSERS_PATH="${BROWSERS_PATH}"

# Playwright only knows how to install Chromium's shared libraries with apt, so this feature is
# Debian and Ubuntu only. Say so before the npm install rather than dying halfway through it.
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

# The node feature hands the global module tree to the remote user, and containers may install more
# global packages as that user at run time. Installing as root would leave root-owned files behind,
# so capture the current ownership and restore it once the install is done.
owner="$(stat -c '%u:%g' "${npm_root}")"

npm install --global "@playwright/cli@${VERSION}"

# @playwright/cli only links its own "playwright-cli" binary; the browser installer lives in its
# playwright-core dependency, whose binary npm leaves unlinked. Locate it rather than assuming
# whether npm hoisted the dependency out of the package's own node_modules.
playwright_core="$(find "${npm_root}" -maxdepth 6 -path '*/playwright-core/cli.js' -print -quit)"

if [ -z "${playwright_core}" ]; then
	echo "playwright-core was not found under ${npm_root}" >&2

	exit 1
fi

# An earlier feature may already have dropped the package lists that install-deps needs.
apt-get update -y

node "${playwright_core}" install-deps chromium
node "${playwright_core}" install chromium

rm -rf /var/lib/apt/lists/*

npm cache clean --force

chown -R "${owner}" "${npm_root}" "$(npm prefix -g)/bin" "${BROWSERS_PATH}"
chmod -R a+rX "${BROWSERS_PATH}"
