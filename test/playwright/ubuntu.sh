#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

BROWSERS_PATH="/usr/local/share/ms-playwright"

check 'check if playwright-cli exists' bash -c "command -v playwright-cli"
check 'check if the browsers path is exported' bash -c "test \"${PLAYWRIGHT_BROWSERS_PATH:-}\" = ${BROWSERS_PATH}"
check 'check if chromium was downloaded' bash -c "ls ${BROWSERS_PATH} | grep -q chromium"
# The checks run as the remote user, so -r and -x prove the browsers survived the chown back to the
# node feature's owner and stay reachable when the home directory is swapped out underneath them.
check 'check if the browsers path is readable by the remote user' bash -c "test -r ${BROWSERS_PATH} && test -x ${BROWSERS_PATH}"
reportResults
