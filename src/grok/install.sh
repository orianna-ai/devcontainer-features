#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
INSTALL_PATH="/usr/local/share/grok"
INSTALLER_URL="https://x.ai/cli/install.sh"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the grok installer" >&2
	exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

staged_bin="${staging}/.grok/bin"

curl -fsSL "${INSTALLER_URL}" -o "${staging}/install.sh"

run_installer() {
	env -u GROK_DEPLOYMENT_KEY -u GROK_PROXY_URL -u GROK_CHANNEL -u GROK_BIN_DIR \
		HOME="${staging}" PATH="${staged_bin}:${PATH}" \
		bash "${staging}/install.sh" "$@"
}

if [ "${VERSION}" = "latest" ]; then
	run_installer
else
	run_installer "${VERSION}"
fi

binary="$(readlink -f "${staged_bin}/grok" || true)"

if [ ! -x "${binary}" ]; then
	echo "the grok installer left no runnable binary at ${staged_bin}/grok" >&2
	exit 1
fi

install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/grok"

for link in /usr/local/bin/grok /usr/local/bin/agent; do
	case "$(readlink "${link}" 2>/dev/null || true)" in
	"${staging}"/*) rm -f "${link}" ;;
	esac
done

ln -sfn "${INSTALL_PATH}/bin/grok" /usr/local/bin/grok

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
