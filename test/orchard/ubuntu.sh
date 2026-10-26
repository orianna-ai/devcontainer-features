#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/orchard

resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v orchard)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/orchard &&
		! test -w "${INSTALL_PATH}/bin/orchard"
}

check 'check if orchard exists' bash -c "command -v orchard"
check 'check if orchard runs' bash -c "orchard --version"
check 'check if orchard resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
