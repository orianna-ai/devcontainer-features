#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/fonts/san-francisco
CONFIG_PATH=/etc/fonts/conf.avail/59-san-francisco.conf

resolves() {
	local requested="$1" expected="$2"
	test "$(fc-match --format '%{family[0]}' "${requested//-/\\-}")" = "${expected}"
}

mono_not_installed() {
	! ls "${INSTALL_PATH}"/SF-Mono-*.otf >/dev/null 2>&1 &&
		! fc-list --format '%{family[0]}\n' | grep -qx 'SF Mono'
}

mono_not_applied() {
	test "$(fc-match --format '%{family[0]}' monospace)" != 'SF Mono'
}

# Asserted against the rules rather than against fc-match: with these off, Arial resolves to
# whatever the image has, and an image carrying no arial-metric font falls through the sans-serif
# generic to SF Pro on its own. That is fontconfig's fallback, not this option, and it varies by
# base image -- so what the option controls is whether the rules are written at all.
no_web_safe_overrides() {
	! grep -q '<string>Arial</string>' "${CONFIG_PATH}" &&
		! grep -q '<string>Helvetica</string>' "${CONFIG_PATH}" &&
		! grep -q 'prepend_first' "${CONFIG_PATH}"
}

check 'check if SF Pro is still installed' bash -c "test -f ${INSTALL_PATH}/SF-Pro.ttf"
check 'check if SF Mono was skipped' mono_not_installed
check 'check if sans-serif still resolves to SF Pro' resolves sans-serif 'SF Pro'
check 'check if system-ui still resolves to SF Pro' resolves system-ui 'SF Pro'
check 'check if monospace does not resolve to SF Mono' mono_not_applied
check 'check if the web-safe sans rules were not written' no_web_safe_overrides
reportResults
