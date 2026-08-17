#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"
INSTALL_PATH=/usr/local/share/typescript-language-server

outside_nvm() {
	case "$(readlink -f "$(command -v typescript-language-server)")" in
	"${NVM_DIR}"/*) return 1 ;;
	esac
}

finds_fallback_tsserver() {
	node -e "
		const path = require('node:path');
		const server = '${INSTALL_PATH}/lib/node_modules/typescript-language-server/lib/cli.mjs';
		const typescript = require('node:module').createRequire(server).resolve('typescript');
		require('node:fs').accessSync(path.join(path.dirname(typescript), 'tsserver.js'));
	"
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/typescript-language-server &&
		! test -w "${INSTALL_PATH}/bin/typescript-language-server"
}

survives_node_switch() {
	# shellcheck source=/dev/null
	. "${NVM_DIR}/nvm.sh" &&
		nvm install 20 >/dev/null &&
		nvm use 20 >/dev/null &&
		test "$(node -v | cut -d. -f1)" = v20 &&
		typescript-language-server --version
}

check 'check if typescript-language-server exists' bash -c "command -v typescript-language-server"
check 'check if typescript-language-server runs' bash -c "typescript-language-server --version"
check 'check if a fallback tsserver resolves from the server tree' finds_fallback_tsserver
check 'check if typescript-language-server lives outside the nvm version directories' outside_nvm
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
# Keep last: repoints nvm's "current" symlink for every later check.
check 'check if typescript-language-server survives a node version switch' survives_node_switch
reportResults
