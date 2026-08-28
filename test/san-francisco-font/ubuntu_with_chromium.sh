#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# What the feature is for: fontconfig agreeing is necessary but not sufficient, because Chromium
# does not ask fontconfig for the CSS generics. It resolves sans-serif through its own default of
# "Arial" and monospace through "Monospace", so only a real render proves the aliases reach it.
# Widths are compared against the families by name -- equal width means the same font was picked.
render_probe() {
	local chrome page
	chrome="$(find "${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/share/ms-playwright}" \
		-path '*/chrome-linux/chrome' -print -quit)"
	test -n "${chrome}" || return 1

	page="$(mktemp --suffix=.html)"
	cat >"${page}" <<'HTML'
<!doctype html><meta charset=utf-8><body><pre id=out></pre><script>
const S = "Handgloves 0123 quick brown fox";
const w = f => { const c = document.createElement("canvas").getContext("2d");
  c.font = "16px " + f; return c.measureText(S).width.toFixed(2); };
const r = [
  ["sans-serif", '"SF Pro"'], ["system-ui", '"SF Pro"'], ["-apple-system", '"SF Pro"'],
  ["Arial", '"SF Pro"'], ["monospace", '"SF Mono"'], ["ui-monospace", '"SF Mono"'],
].every(([asked, want]) => w(asked) === w(want));
// Guards the comparison itself: if SF Pro were missing, every name would fall back together and
// each pair above would match on the fallback's width.
const distinct = w('"SF Pro"') !== w('"DejaVu Sans"') && w('"SF Mono"') !== w('"DejaVu Sans Mono"');
// Assembled at run time on purpose: --dump-dom prints this script's own source alongside the
// DOM, so a marker written out whole here would be matched even when the check fails.
document.getElementById("out").textContent = "verdict:" + ((r && distinct) ? "yes" : "no");
</script></body>
HTML

	"${chrome}" --headless --no-sandbox --disable-gpu --virtual-time-budget=5000 \
		--dump-dom "file://${page}" 2>/dev/null | grep -q 'verdict:yes'
}

check 'check if the fonts are installed' bash -c "test -f /usr/local/share/fonts/san-francisco/SF-Pro.ttf"
check 'check if chromium renders the generic families with san francisco' render_probe
reportResults
