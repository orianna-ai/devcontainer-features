#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Chromium does not ask fontconfig for the CSS generics, so only a real render proves these reach it.
render_probe() {
	local chrome work dom
	chrome="$(find "${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/share/ms-playwright}" \
		-path '*/chrome-linux/chrome' -print -quit)"
	test -n "${chrome}" || return 1

	work="$(mktemp -d)"

	cat >"${work}/probe.js" <<'JS'
const S = "Handgloves 0123 quick brown fox";
const w = f => { const c = document.createElement("canvas").getContext("2d");
  c.font = "16px " + f; return c.measureText(S).width.toFixed(2); };
const want = { "SF Pro": w('"SF Pro"'), "SF Mono": w('"SF Mono"') };
const probes = [["sans-serif", "SF Pro"], ["system-ui", "SF Pro"], ["-apple-system", "SF Pro"],
  ["Arial", "SF Pro"], ["monospace", "SF Mono"], ["ui-monospace", "SF Mono"]];
const ok = probes.every(([asked, target]) => w(asked) === want[target])
  && want["SF Pro"] !== want["SF Mono"];
document.getElementById("out").textContent =
  probes.map(([asked, target]) =>
    asked + "=" + w(asked) + (w(asked) === want[target] ? "==" : "!=") + target).join(" ") +
  " | SF Pro=" + want["SF Pro"] + " SF Mono=" + want["SF Mono"] +
  " | verdict:" + (ok ? "yes" : "no");
JS

	cat >"${work}/probe.html" <<'HTML'
<!doctype html><meta charset=utf-8><pre id=out></pre><script src="probe.js"></script>
HTML

	dom="$("${chrome}" --headless --no-sandbox --disable-gpu --virtual-time-budget=5000 \
		--dump-dom "file://${work}/probe.html" 2>/dev/null)"

	echo "${dom}" | sed -n 's/.*<pre id="out">\(.*\)<\/pre>.*/\1/p'
	echo "${dom}" | grep -q 'verdict:yes'
}

check 'check if the fonts are installed' bash -c "test -f /usr/local/share/fonts/san-francisco/SF-Pro.ttf"
check 'check if chromium renders the generic families with san francisco' render_probe
reportResults
