#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/fonts/san-francisco

# An unescaped hyphen starts fc-match's property list, so "system-ui" would ask for "system".
resolves() {
	local requested="$1" expected="$2"
	test "$(fc-match --format '%{family[0]}' "${requested//-/\\-}")" = "${expected}"
}

installed() {
	test -f "${INSTALL_PATH}/SF-Pro.ttf" &&
		test -f "${INSTALL_PATH}/SF-Pro-Italic.ttf" &&
		ls "${INSTALL_PATH}"/SF-Mono-*.otf >/dev/null 2>&1
}

# Guards the variable font's named instances, without which every weight collapses onto Regular.
has_every_weight() {
	local style
	for style in Ultralight Regular Semibold Bold Black; do
		fc-list --format '%{style[0]}\n' 'SF Pro' | grep -qx "${style}" || return 1
	done
	fc-list --format '%{style[0]}\n' 'SF Pro' | grep -qx 'Regular Italic'
}

enabled_through_conf_d() {
	test -L /etc/fonts/conf.d/59-san-francisco.conf &&
		test -f /etc/fonts/conf.avail/59-san-francisco.conf
}

leaves_serif_alone() {
	case "$(fc-match --format '%{family[0]}' serif)" in
	SF*) return 1 ;;
	*) return 0 ;;
	esac
}

no_build_only_archiver() {
	! command -v 7zz >/dev/null 2>&1 &&
		! command -v 7z >/dev/null 2>&1 &&
		! command -v 7za >/dev/null 2>&1
}

not_writable_by_remote_user() {
	! test -w "${INSTALL_PATH}/SF-Pro.ttf" &&
		! test -w /etc/fonts/conf.avail/59-san-francisco.conf
}

check 'check if the fonts are installed' installed
check 'check if the fonts are readable by the remote user' bash -c "test -r ${INSTALL_PATH}/SF-Pro.ttf"
check 'check if every weight and the italic are registered' has_every_weight
check 'check if the fontconfig rules are enabled through conf.d' enabled_through_conf_d
check 'check if sans-serif resolves to SF Pro' resolves sans-serif 'SF Pro'
check 'check if system-ui resolves to SF Pro' resolves system-ui 'SF Pro'
check 'check if -apple-system resolves to SF Pro' resolves -apple-system 'SF Pro'
check 'check if BlinkMacSystemFont resolves to SF Pro' resolves BlinkMacSystemFont 'SF Pro'
check 'check if Arial resolves to SF Pro' resolves Arial 'SF Pro'
check 'check if Helvetica resolves to SF Pro' resolves Helvetica 'SF Pro'
check 'check if monospace resolves to SF Mono' resolves monospace 'SF Mono'
check 'check if ui-monospace resolves to SF Mono' resolves ui-monospace 'SF Mono'
check 'check if serif is left alone' leaves_serif_alone
check 'check if the archiver was not left in the image' no_build_only_archiver
check 'check if the install is read-only to the remote user' not_writable_by_remote_user
reportResults
