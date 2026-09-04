#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/antigravity

# Guards the installer's own layout, which leaves the binary in a home directory.
resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v agy)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

runs_without_credentials() {
	test ! -e "${HOME}/.gemini/antigravity-cli/settings.json" &&
		test -z "${GEMINI_API_KEY:-}" &&
		agy --version
}

# The installer's default target is $HOME/.local/bin and it stages its download through
# $HOME/.cache/antigravity. Staging HOME during the build is what keeps both out of the image.
leaves_nothing_in_the_home_directory() {
	test ! -e "${HOME}/.local/bin/agy" &&
		test ! -e "${HOME}/.cache/antigravity"
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/agy &&
		! test -w "${INSTALL_PATH}/bin/agy"
}

check 'check if agy exists' bash -c "command -v agy"
check 'check if agy runs' bash -c "agy --version"
check 'check if agy resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if agy runs without any credential' runs_without_credentials
check 'check if the installer left nothing in the home directory' leaves_nothing_in_the_home_directory
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
