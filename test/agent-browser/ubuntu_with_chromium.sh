#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# The pairing this feature relies on for a browser: the playwright feature downloads a browser and
# exports PLAYWRIGHT_BROWSERS_PATH, and agent-browser is expected to find it with nothing
# configured. Only driving a real page proves that, so that is the first check.
SESSION=featuretest

drives_a_page() {
	local work
	work="$(mktemp -d)"

	cat >"${work}/probe.html" <<'HTML'
<!doctype html><meta charset=utf-8><title>probe</title><h1 id=h>agent-browser works</h1>
HTML

	if ! agent-browser --session "${SESSION}" open "file://${work}/probe.html" >/dev/null; then
		# Names the browser it looked for and where, which is the whole diagnosis when the
		# pairing is what broke.
		agent-browser doctor || true
		return 1
	fi

	test "$(agent-browser --session "${SESSION}" get text '#h')" = 'agent-browser works' &&
		agent-browser --session "${SESSION}" screenshot "${work}/shot.png" >/dev/null &&
		test -s "${work}/shot.png" &&
		agent-browser --session "${SESSION}" close >/dev/null
}

# Which browser it picked, rather than merely that some browser worked. Only the path is asserted:
# the version string is the browser's own, and playwright ships builds that call themselves
# "Chromium" or "Google Chrome for Testing" depending on the release.
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
