#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/fleetctl

resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v fleetctl)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/fleetctl &&
		! test -w "${INSTALL_PATH}/bin/fleetctl"
}

check 'check if fleetctl exists' bash -c "command -v fleetctl"
check 'check if fleetctl runs' bash -c "fleetctl --version"
check 'check if fleetctl resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
