#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# With no real key the first decision is refused by TypeSafe, which only happens after the CLI has
# launched Chromium, attached Browser Harness to it and read the page. So a JSON report that names
# the provider's 401 and carries the probe page's text proves the whole browser half works.
observes_a_page_up_to_the_model_call() {
	local work report
	work="$(mktemp -d)"

	cat >"${work}/probe.html" <<'HTML'
<!doctype html><meta charset=utf-8><title>probe</title><h1>jev works</h1><button>Go</button>
HTML

	report="$(TYPESAFE_API_KEY=invalid jev-ultrafast --url "file://${work}/probe.html" --goal 'Click Go' || true)"
	echo "${report}"

	echo "${report}" | grep -q '"title": "probe"' &&
		echo "${report}" | grep -q 'jev works' &&
		echo "${report}" | grep -q 'HTTP 401'
}

leaves_no_browser_behind() {
	! pgrep -u "$(id -u)" -f -- '--user-data-dir=.*jev-ultrafast-' >/dev/null
}

check 'check if jev-ultrafast drives chromium up to the model call' observes_a_page_up_to_the_model_call
check 'check if jev-ultrafast stops the browser it launched' leaves_no_browser_behind
reportResults
