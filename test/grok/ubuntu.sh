#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/grok

# Guards the installer's own layout, which leaves the binary in a home directory.
resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v grok)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

runs_without_credentials() {
	test ! -e "${HOME}/.grok/auth.json" &&
		test -z "${GROK_DEPLOYMENT_KEY:-}" &&
		grok --version
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/grok &&
		! test -w "${INSTALL_PATH}/bin/grok"
}

check 'check if grok exists' bash -c "command -v grok"
check 'check if grok runs' bash -c "grok --version"
check 'check if grok resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if grok runs without any credential' runs_without_credentials
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
