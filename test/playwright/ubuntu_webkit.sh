#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

check 'check if the full chromium was downloaded' bash -c "test -x /usr/local/share/ms-playwright/chromium-*/chrome-linux*/chrome"
check 'check if webkit was downloaded' bash -c "test -x /usr/local/share/ms-playwright/webkit-*/pw_run.sh"
check 'check if the default browser is still chromium' bash -c "test \"${PLAYWRIGHT_MCP_BROWSER:-}\" = chromium"
check 'check if webkit opens' bash -c "PLAYWRIGHT_CLI_SESSION=featurewebkit playwright-cli open --browser=webkit && PLAYWRIGHT_CLI_SESSION=featurewebkit playwright-cli close"
reportResults
