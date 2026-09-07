#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# The feature installs no browser and relies on agent-browser finding playwright's through
# PLAYWRIGHT_BROWSERS_PATH, so only driving a real page proves the pairing. Which browser it picked
# is asserted by path alone -- the version string is the browser's own, and playwright ships builds
# calling themselves "Chromium" and builds calling themselves "Google Chrome for Testing".
SESSION=featuretest

drives_a_page() {
	local work
	work="$(mktemp -d)"

	cat >"${work}/probe.html" <<'HTML'
<!doctype html><meta charset=utf-8><title>probe</title><h1 id=h>agent-browser works</h1>
HTML

	if ! agent-browser --session "${SESSION}" open "file://${work}/probe.html" >/dev/null; then
		agent-browser doctor || true
		return 1
	fi

	test "$(agent-browser --session "${SESSION}" get text '#h')" = 'agent-browser works' &&
		agent-browser --session "${SESSION}" screenshot "${work}/shot.png" >/dev/null &&
		test -s "${work}/shot.png" &&
		agent-browser --session "${SESSION}" close >/dev/null
}

resolves_inside_the_playwright_cache() {
	local browsers report
	browsers="${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/share/ms-playwright}"
	report="$(agent-browser doctor)"

	echo "${report}" | grep -E '^  (pass|warn|fail)  ' | grep -iE 'chrom|browser'

	echo "${report}" | grep -qE "^  pass  .+ at ${browsers}/"
}

check 'check if agent-browser exists' bash -c "command -v agent-browser"
check 'check if agent-browser drives a page with no browser configured' drives_a_page
check 'check if the browser it picked came from the playwright cache' resolves_inside_the_playwright_cache
reportResults
