#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Chromium does not ask fontconfig for the CSS generics, so only a real render proves the aliases
# reach it. Equal text width against a family named outright means the same font was picked.
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
// Without this every name could fall back together and each pair above would match on the fallback.
const distinct = w('"SF Pro"') !== w('"DejaVu Sans"') && w('"SF Mono"') !== w('"DejaVu Sans Mono"');
// Assembled at run time: --dump-dom prints this script's source too, so a whole marker would match.
document.getElementById("out").textContent = "verdict:" + ((r && distinct) ? "yes" : "no");
</script></body>
HTML

	"${chrome}" --headless --no-sandbox --disable-gpu --virtual-time-budget=5000 \
		--dump-dom "file://${page}" 2>/dev/null | grep -q 'verdict:yes'
}

check 'check if the fonts are installed' bash -c "test -f /usr/local/share/fonts/san-francisco/SF-Pro.ttf"
check 'check if chromium renders the generic families with san francisco' render_probe
reportResults
