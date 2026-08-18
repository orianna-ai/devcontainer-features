#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

runtime_node() {
	set -- /usr/local/share/node-runtime/v*/bin/node
	echo "$1"
}

no_node_on_path() {
	! command -v node >/dev/null 2>&1 &&
		! command -v npm >/dev/null 2>&1
}

runtime_installed() {
	test -x "$(runtime_node)"
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/playwright-cli &&
		! test -w /usr/local/share/playwright-cli/bin/playwright-cli &&
		! test -w "$(runtime_node)"
}

check 'check the image has no node of its own' no_node_on_path
check 'check if playwright-cli exists' bash -c "command -v playwright-cli"
check 'check if playwright-cli runs' bash -c "playwright-cli --version"
check 'check if the private runtime was installed' runtime_installed
check 'check if chromium was downloaded' bash -c "ls /usr/local/share/ms-playwright | grep -q chromium"
check 'check if the browser opens with no --browser flag' bash -c "PLAYWRIGHT_CLI_SESSION=featuretest playwright-cli open && PLAYWRIGHT_CLI_SESSION=featuretest playwright-cli close"
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
