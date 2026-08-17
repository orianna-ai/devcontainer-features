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

# Stage a HOME rather than setting GROK_BIN_DIR. The installer downloads into a hardcoded
# "$HOME/.grok/downloads" and only symlinks "$BIN_DIR/grok" at it, so pointing BIN_DIR alone at a
# shared prefix leaves that link aimed into root's home — a path the remote user cannot read. A
# staged HOME keeps the binary and its link together; the binary is copied out below and the
# staging directory is dropped, so nothing in the image depends on it.
#
# The staged bin directory goes on PATH for the same reason. When its own bin directory is not
# already on PATH, the installer helpfully symlinks grok AND agent into the first writable PATH
# entry it finds — /usr/local/bin during an image build — aimed at the staging directory, which
# then dangles the moment staging is removed. Putting it on PATH takes that branch away.
#
# The staged HOME has no ".grok/auth.json", and no GROK_DEPLOYMENT_KEY is set, so the installer
# takes its unauthenticated path and pulls the public stable build — a credential on the build
# machine can never leak into the image.
if [ "${VERSION}" = "latest" ]; then
	HOME="${staging}" PATH="${staged_bin}:${PATH}" bash "${staging}/install.sh"
else
	HOME="${staging}" PATH="${staged_bin}:${PATH}" bash "${staging}/install.sh" "${VERSION}"
fi

binary="$(readlink -f "${staged_bin}/grok")"

if [ ! -x "${binary}" ]; then
	echo "the grok installer left no runnable binary at ${staged_bin}/grok" >&2
	exit 1
fi

install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/grok"

# Belt and braces for the PATH branch above: if a future installer links into /usr/local/bin
# anyway, those links point into staging and would ship broken. The installer's only other
# candidate, "$HOME/.local/bin", is inside staging and goes with it.
for link in /usr/local/bin/grok /usr/local/bin/agent; do
	case "$(readlink "${link}" 2>/dev/null || true)" in
	"${staging}"/*) rm -f "${link}" ;;
	esac
done

ln -sfn "${INSTALL_PATH}/bin/grok" /usr/local/bin/grok

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
