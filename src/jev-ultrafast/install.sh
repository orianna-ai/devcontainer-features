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

case "$(uname -m)" in
x86_64) uv_target=x86_64-unknown-linux-gnu uv_sha256=920cbcaad514cc185634f6f0dcd71df5e8f4ee4456d440a22e0f8c0f142a8203 ;;
aarch64) uv_target=aarch64-unknown-linux-gnu uv_sha256=9a20d65b110770bbaa2ee89ed76eb963d8c6a480b9ebef584ea9df2ae85b4f0f ;;
*)
	echo "unsupported architecture $(uname -m); uv ships linux builds for x86_64 and aarch64 only" >&2
	exit 1
	;;
esac

# A private uv, used for the build only and discarded with the staging directory, so the feature
# neither needs nor disturbs whichever uv the image carries. The release archive is checked
# against a pinned digest before anything in it runs.
curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-${uv_target}.tar.gz" \
	-o "${staging}/uv.tar.gz"
echo "${uv_sha256}  ${staging}/uv.tar.gz" | sha256sum -c - >/dev/null
tar -xzf "${staging}/uv.tar.gz" -C "${staging}" --strip-components=1 "uv-${uv_target}/uv"
uv="${staging}/uv"

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
