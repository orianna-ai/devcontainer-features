#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/jev-ultrafast

resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v jev-ultrafast)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

imports_the_agent() {
	"${INSTALL_PATH}/venv/bin/python" -c 'import jev_ultrafast, browser_harness'
}

refuses_without_a_key() {
	! env -u TYPESAFE_API_KEY jev-ultrafast --url about:blank --goal probe 2>"${HOME}/err" &&
		grep -q 'TYPESAFE_API_KEY is not set' "${HOME}/err"
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/jev-ultrafast &&
		! test -w "${INSTALL_PATH}/bin/jev-ultrafast" &&
		! test -w "${INSTALL_PATH}/venv/bin/python"
}

check 'check if jev-ultrafast exists' bash -c "command -v jev-ultrafast"
check 'check if jev-ultrafast runs' bash -c "jev-ultrafast --help"
check 'check if the agent imports under the private interpreter' imports_the_agent
check 'check if jev-ultrafast resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if jev-ultrafast refuses to run without a TypeSafe key' refuses_without_a_key
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
