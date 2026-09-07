#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# The pairing this feature relies on for a browser: the playwright feature downloads Chromium and
# exports PLAYWRIGHT_BROWSERS_PATH, and agent-browser is expected to find it with nothing
# configured. Only driving a real page proves that, so the checks below launch one.
SESSION=featuretest

finds_the_playwright_chromium() {
	agent-browser doctor | grep -qE '^  pass  Chromium .* at '"${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/share/ms-playwright}"'/'
}

drives_a_page() {
	local work
	work="$(mktemp -d)"

	cat >"${work}/probe.html" <<'HTML'
<!doctype html><meta charset=utf-8><title>probe</title><h1 id=h>agent-browser works</h1>
HTML

	agent-browser --session "${SESSION}" open "file://${work}/probe.html" >/dev/null &&
		test "$(agent-browser --session "${SESSION}" get text '#h')" = 'agent-browser works' &&
		agent-browser --session "${SESSION}" screenshot "${work}/shot.png" >/dev/null &&
		test -s "${work}/shot.png" &&
		agent-browser --session "${SESSION}" close >/dev/null
}

check 'check if agent-browser exists' bash -c "command -v agent-browser"
check 'check if agent-browser finds the playwright chromium' finds_the_playwright_chromium
check 'check if agent-browser drives a page with no browser configured' drives_a_page
reportResults
