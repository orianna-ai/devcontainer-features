#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-1.101.0}"
PYTHON_VERSION="${PYTHONVERSION:-3.13}"
INSTALL_PATH="/usr/local/share/litellm"

# uv is only a build tool here: a pinned release, verified against the digest PyPI publishes for
# it, staged for the install and gone with the staging directory. Bump the version and both
# digests together (https://pypi.org/pypi/uv/<version>/json lists them).
UV_VERSION="0.12.15"
UV_X86_64_WHEEL="https://files.pythonhosted.org/packages/1e/fd/432451d732917c49152a291de3ef171aa6b0f1a22d39780fb2c1f085ca4c/uv-0.12.15-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
UV_X86_64_SHA256="aee9802f46bae436bd91751bb33ddeb379ef1596b5c19df193219d545d244b60"
UV_AARCH64_WHEEL="https://files.pythonhosted.org/packages/e9/3a/52e6f0c159d133b03890b5c54823bdc10163ce6f010515f649e5804b5bba/uv-0.12.15-py3-none-manylinux_2_28_aarch64.whl"
UV_AARCH64_SHA256="013e3a5774fb2cc036a9422edc51c8c5273cca011ec04c2817249b8a4a0b0f02"

for tool in curl dpkg sha256sum unzip; do
	if ! command -v "${tool}" >/dev/null 2>&1; then
		echo "${tool} was not found; it is needed to fetch and unpack the pinned uv release" >&2
		exit 1
	fi
done

case "$(dpkg --print-architecture)" in
amd64)
	wheel="${UV_X86_64_WHEEL}"
	sha256="${UV_X86_64_SHA256}"
	;;
arm64)
	wheel="${UV_AARCH64_WHEEL}"
	sha256="${UV_AARCH64_SHA256}"
	;;
*)
	echo "unsupported architecture $(dpkg --print-architecture); uv ships linux builds for amd64 and arm64 only" >&2
	exit 1
	;;
esac

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

curl -fsSL "${wheel}" -o "${staging}/uv.whl"
echo "${sha256}  ${staging}/uv.whl" | sha256sum -c - >/dev/null

# The wheel carries the binary under its scripts directory; nothing else in it is needed.
unzip -q -j "${staging}/uv.whl" "uv-${UV_VERSION}.data/scripts/uv" -d "${staging}/uv"
chmod 0755 "${staging}/uv/uv"

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
