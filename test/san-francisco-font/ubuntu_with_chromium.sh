#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Chromium does not ask fontconfig for the CSS generics, so only a real render proves these reach
# it -- and the full browser and the headless shell do not resolve them the same way, so both are
# probed. chrome-linux is playwright's own chromium build, chrome-linux64 the chrome-for-testing
# build it switched to.
render_probe() {
	local browsers work browser dom report found=0 failed=0
	browsers="${PLAYWRIGHT_BROWSERS_PATH:-/usr/local/share/ms-playwright}"
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

	while IFS= read -r browser; do
		found=1

		dom="$("${browser}" --headless --no-sandbox --disable-gpu --disable-dev-shm-usage \
			--virtual-time-budget=5000 --dump-dom "file://${work}/probe.html" 2>"${work}/stderr")"
		report="$(echo "${dom}" | sed -n 's/.*<pre id="out">\(.*\)<\/pre>.*/\1/p')"

		if [ -z "${report}" ]; then
			echo "$(basename "${browser}") produced no probe output; it said:"
			head -c 300 "${work}/stderr"
			failed=1
			continue
		fi

		echo "$(basename "${browser}") ${report}"

		case "${report}" in
		*verdict:yes) ;;
		*) failed=1 ;;
		esac
	done < <(find "${browsers}" \
		\( -path '*/chrome-linux*/chrome' -o -path '*/chrome-linux*/headless_shell' \) 2>/dev/null)

	if [ "${found}" -eq 0 ]; then
		echo "no chromium under ${browsers}; it holds:"
		find "${browsers}" -maxdepth 2 -mindepth 1 -type d 2>/dev/null
		return 1
	fi

	return "${failed}"
}

check 'check if the fonts are installed' bash -c "test -f /usr/local/share/fonts/san-francisco/SF-Pro.ttf"
check 'check if chromium renders the generic families with san francisco' render_probe
reportResults
