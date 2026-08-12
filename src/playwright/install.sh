#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
BROWSERS_PATH="/usr/local/share/ms-playwright"
INSTALL_PATH="/usr/local/share/playwright-cli"
MCP_BROWSER="chromium"

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

# Not "npm install --global": nvm's global root is one directory per node version, so the package and
# its bin shim would vanish from PATH the moment someone runs "nvm use" or "nvm install". Own prefix,
# symlinked into /usr/local/bin, keeps one copy that every node version — and sudo — resolves.
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

# A symlink would be enough to find the CLI, but not to run it: npm's launcher resolves node through
# "env", and the callers that most need a stable path — sudo, cron — hand it a PATH with no nvm
# directory in it. The wrapper resolves node itself, and only when the caller has none, so an
# ordinary shell still runs the CLI on whichever version it already has active.
cat >/usr/local/bin/playwright-cli <<EOF
#!/bin/sh
if ! command -v node >/dev/null 2>&1; then
	PATH="\${NVM_DIR:-/usr/local/share/nvm}/current/bin:\${PATH}"
	export PATH
fi

# Those same callers drop containerEnv, which is the only thing pointing the CLI at this image's
# browsers: without it playwright looks for them under HOME, and defaults to the branded chrome
# channel at /opt/google/chrome/chrome that nothing here installs.
PLAYWRIGHT_BROWSERS_PATH="\${PLAYWRIGHT_BROWSERS_PATH:-${BROWSERS_PATH}}"
PLAYWRIGHT_MCP_BROWSER="\${PLAYWRIGHT_MCP_BROWSER:-${MCP_BROWSER}}"
export PLAYWRIGHT_BROWSERS_PATH PLAYWRIGHT_MCP_BROWSER

exec "${INSTALL_PATH}/bin/playwright-cli" "\$@"
EOF
chmod 0755 /usr/local/bin/playwright-cli

# Deliberately not chowned to the remote user: /usr/local/bin/playwright-cli is reachable through
# sudo, so what it executes stays root-owned and read-only to everyone else.
chown -R "${owner}" "${BROWSERS_PATH}"
chmod -R a+rX "${INSTALL_PATH}" "${BROWSERS_PATH}"
