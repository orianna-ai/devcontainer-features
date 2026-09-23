#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-1231850a0bf1a0c0341fe408ef1668dbbfdfac46}"
PYTHON_VERSION="${PYTHONVERSION:-3.13}"
UV_VERSION="0.8.17"
REPOSITORY="https://github.com/browser-use/jev-ultrafast"
INSTALL_PATH="/usr/local/share/jev-ultrafast"
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch uv" >&2
	exit 1
fi

if ! command -v git >/dev/null 2>&1; then
	echo "git was not found; it is needed to fetch jev-ultrafast from ${REPOSITORY}" >&2
	exit 1
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

# A private uv, used for the build only and discarded with the staging directory, so the feature
# neither needs nor disturbs whichever uv the image carries.
curl -fsSL "https://astral.sh/uv/${UV_VERSION}/install.sh" |
	env UV_UNMANAGED_INSTALL="${staging}/uv" INSTALLER_NO_MODIFY_PATH=1 sh >/dev/null
uv="${staging}/uv/uv"

export UV_CACHE_DIR="${staging}/cache"
export UV_PYTHON_INSTALL_DIR="${INSTALL_PATH}/python"
export UV_PYTHON_PREFERENCE=only-managed

rm -rf "${INSTALL_PATH}"
mkdir -p "${INSTALL_PATH}/bin"

"${uv}" python install "${PYTHON_VERSION}"
"${uv}" venv --python "${PYTHON_VERSION}" "${INSTALL_PATH}/venv"
"${uv}" pip install --python "${INSTALL_PATH}/venv/bin/python" \
	"jev-ultrafast @ git+${REPOSITORY}@${VERSION}"

{
	echo "#!${INSTALL_PATH}/venv/bin/python"
	cat "${FEATURE_DIR}/jev-ultrafast.py"
} >"${INSTALL_PATH}/bin/jev-ultrafast"
chmod 0755 "${INSTALL_PATH}/bin/jev-ultrafast"

ln -sfn "${INSTALL_PATH}/bin/jev-ultrafast" /usr/local/bin/jev-ultrafast

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

"${INSTALL_PATH}/venv/bin/python" -c "import jev_ultrafast, browser_harness"
jev-ultrafast --help >/dev/null
