#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
NODE_VERSION="${NODEVERSION:-24.18.0}"
BROWSERS_PATH="/usr/local/share/ms-playwright"
INSTALL_PATH="/usr/local/share/playwright-cli"
RUNTIME="/usr/local/share/node-runtime/v${NODE_VERSION}"
NODE="${RUNTIME}/bin/node"

export DEBIAN_FRONTEND=noninteractive
export PLAYWRIGHT_BROWSERS_PATH="${BROWSERS_PATH}"

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get was not found; this feature only supports debian and ubuntu base images" >&2
	exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the private node runtime" >&2
	exit 1
fi

install_node_runtime() {
	if [ -x "${NODE}" ]; then
		return
	fi

	local arch
	case "$(dpkg --print-architecture)" in
	amd64) arch=x64 ;;
	arm64) arch=arm64 ;;
	*)
		echo "unsupported architecture $(dpkg --print-architecture); node ships linux builds for amd64 and arm64 only" >&2
		exit 1
		;;
	esac

	local staging tarball
	staging="$(mktemp -d)"
	tarball="node-v${NODE_VERSION}-linux-${arch}.tar.gz"

	curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}" -o "${staging}/${tarball}"
	curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o "${staging}/SHASUMS256.txt"
	(cd "${staging}" && grep " ${tarball}\$" SHASUMS256.txt | sha256sum -c -)

	mkdir -p "${RUNTIME}"
	tar -xzf "${staging}/${tarball}" -C "${RUNTIME}" --strip-components=1
	rm -rf "${staging}"

	chown -R root:root "${RUNTIME}"
	chmod -R a+rX,go-w "${RUNTIME}"
}

npm() {
	env PATH="${RUNTIME}/bin:${PATH}" npm_config_cache="${npm_cache}" \
		"${NODE}" "${RUNTIME}/lib/node_modules/npm/bin/npm-cli.js" "$@"
}

install_node_runtime

npm_cache="$(mktemp -d)"
trap 'rm -rf "${npm_cache}"' EXIT

npm install --global --prefix "${INSTALL_PATH}" "@playwright/cli@${VERSION}"

node_modules="${INSTALL_PATH}/lib/node_modules"
playwright_core="$(find "${node_modules}" -maxdepth 6 -path '*/playwright-core/cli.js' -print -quit)"

if [ -z "${playwright_core}" ]; then
	echo "playwright-core was not found under ${node_modules}" >&2
	exit 1
fi

apt-get update -y

"${NODE}" "${playwright_core}" install-deps chromium
"${NODE}" "${playwright_core}" install chromium

rm -rf /var/lib/apt/lists/*

cat >/usr/local/bin/playwright-cli <<EOF
#!/bin/sh
exec "${NODE}" "${INSTALL_PATH}/bin/playwright-cli" "\$@"
EOF
chmod 0755 /usr/local/bin/playwright-cli

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

remote_user="${_REMOTE_USER:-root}"
if ! id -u "${remote_user}" >/dev/null 2>&1; then
	remote_user=root
fi

chown -R "${remote_user}" "${BROWSERS_PATH}"
chmod -R a+rX "${BROWSERS_PATH}"
