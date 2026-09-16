#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
PYTHON_VERSION="${PYTHONVERSION:-3.13}"
INSTALL_PATH="/usr/local/share/litellm"
UV_INSTALLER_URL="https://astral.sh/uv/install.sh"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the uv installer" >&2
	exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

# uv is only a build tool here: it lands in staging and leaves with it.
curl -fsSL "${UV_INSTALLER_URL}" -o "${staging}/uv-install.sh"
env UV_UNMANAGED_INSTALL="${staging}/uv" UV_NO_MODIFY_PATH=1 sh "${staging}/uv-install.sh" >/dev/null

if [ "${VERSION}" = "latest" ]; then
	requirement="litellm[proxy]"
else
	requirement="litellm[proxy]==${VERSION}"
fi

# Everything the proxy needs at run time — the interpreter, the tool venv, the launcher — lands
# under the shared prefix. HOME and the cache are staged so nothing is left in a home directory.
env HOME="${staging}" \
	UV_CACHE_DIR="${staging}/cache" \
	UV_PYTHON_INSTALL_DIR="${INSTALL_PATH}/python" \
	UV_PYTHON_PREFERENCE=only-managed \
	UV_TOOL_DIR="${INSTALL_PATH}/tools" \
	UV_TOOL_BIN_DIR="${INSTALL_PATH}/bin" \
	"${staging}/uv/uv" tool install --python "${PYTHON_VERSION}" "${requirement}"

if [ ! -x "${INSTALL_PATH}/bin/litellm" ]; then
	echo "uv left no runnable launcher at ${INSTALL_PATH}/bin/litellm" >&2
	exit 1
fi

ln -sfn "${INSTALL_PATH}/bin/litellm" /usr/local/bin/litellm

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
