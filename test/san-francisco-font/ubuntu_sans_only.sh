#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

FONTS_PATH=/usr/local/share/fonts/san-francisco

# See ubuntu.sh: an unescaped hyphen would be read as the start of fc-match's property list.
resolves() {
	local requested="$1" expected="$2"
	test "$(fc-match --format '%{family[0]}' "${requested//-/\\-}")" = "${expected}"
}

not_san_francisco() {
	case "$(fc-match --format '%{family[0]}' "${1//-/\\-}")" in
	SF*) return 1 ;;
	*) return 0 ;;
	esac
}

mono_not_installed() {
	! ls "${FONTS_PATH}"/SF-Mono-*.otf >/dev/null 2>&1 &&
		! fc-list --format '%{family[0]}\n' | grep -qx 'SF Mono'
}

check 'check if SF Pro is still installed' bash -c "test -f ${FONTS_PATH}/SF-Pro.ttf"
check 'check if SF Mono was skipped' mono_not_installed
check 'check if sans-serif still resolves to SF Pro' resolves sans-serif 'SF Pro'
check 'check if system-ui still resolves to SF Pro' resolves system-ui 'SF Pro'
check 'check if monospace is left alone' not_san_francisco monospace
check 'check if Arial is left alone' not_san_francisco Arial
check 'check if Helvetica is left alone' not_san_francisco Helvetica
reportResults
