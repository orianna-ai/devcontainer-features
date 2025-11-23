#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib
check 'check if bb exists' bash -c 'which bb' | grep '/usr/bin/bb'
reportResults
