#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

NVM_DIR="${NVM_DIR:-/usr/local/share/nvm}"

outside_nvm() {
	case "$(readlink -f "$(command -v playwright-cli)")" in
	"${NVM_DIR}"/*) return 1 ;;
	esac
}

survives_node_switch() {
	# shellcheck source=/dev/null
	. "${NVM_DIR}/nvm.sh" &&
		nvm install 20 >/dev/null &&
		nvm use 20 >/dev/null &&
		test "$(node -v | cut -d. -f1)" = v20 &&
		playwright-cli --version
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/playwright-cli &&
		! test -w /usr/local/share/playwright-cli/bin/playwright-cli
}

check 'check if playwright-cli exists' bash -c "command -v playwright-cli"
check 'check if the browsers path is exported' bash -c "test \"${PLAYWRIGHT_BROWSERS_PATH:-}\" = /usr/local/share/ms-playwright"
check 'check if the default browser is chromium' bash -c "test \"${PLAYWRIGHT_MCP_BROWSER:-}\" = chromium"
check 'check if chromium was downloaded' bash -c "ls /usr/local/share/ms-playwright | grep -q chromium"
check 'check if the browsers are readable by the remote user' bash -c "test -r /usr/local/share/ms-playwright && test -x /usr/local/share/ms-playwright"
check 'check if the browser opens with no --browser flag' bash -c "PLAYWRIGHT_CLI_SESSION=featuretest playwright-cli open && PLAYWRIGHT_CLI_SESSION=featuretest playwright-cli close"
check 'check if playwright-cli lives outside the nvm version directories' outside_nvm
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
# Keep last: repoints nvm's "current" symlink for every later check.
check 'check if playwright-cli survives a node version switch' survives_node_switch
reportResults
