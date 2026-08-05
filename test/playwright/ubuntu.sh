#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib
check 'check if playwright-cli exists' bash -c "command -v playwright-cli"
check 'check if the browsers path is exported' bash -c "test \"${PLAYWRIGHT_BROWSERS_PATH:-}\" = /usr/local/share/ms-playwright"
check 'check if chromium was downloaded' bash -c "ls /usr/local/share/ms-playwright | grep -q chromium"
check 'check if the browsers are readable by the remote user' bash -c "test -r /usr/local/share/ms-playwright && test -x /usr/local/share/ms-playwright"
reportResults
