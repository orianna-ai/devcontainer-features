#!/bin/bash
set -e

which bb

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib
check 'check if bb exists' bash -c "command -v bb"
reportResults
