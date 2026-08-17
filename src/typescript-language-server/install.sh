#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
TYPESCRIPT_VERSION="${TYPESCRIPTVERSION:-6}"
INSTALL_PATH="/usr/local/share/typescript-language-server"

if ! command -v npm >/dev/null 2>&1; then
	export NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"

	# shellcheck source=/dev/null
	[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
fi

if ! command -v npm >/dev/null 2>&1; then
	echo "npm was not found; this feature has to install after the node feature" >&2
	exit 1
fi

npm install --global --engine-strict --prefix "${INSTALL_PATH}" \
	"typescript-language-server@${VERSION}" \
	"typescript@${TYPESCRIPT_VERSION}"

npm cache clean --force

if [ ! -f "${INSTALL_PATH}/lib/node_modules/typescript/lib/tsserver.js" ]; then
	echo "typescript@${TYPESCRIPT_VERSION} does not ship lib/tsserver.js, which typescript-language-server runs; use a version below 7" >&2
	exit 1
fi

ln -sfn "${INSTALL_PATH}/bin/typescript-language-server" /usr/local/bin/typescript-language-server

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
