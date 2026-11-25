#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

check 'check if litellm exists' bash -c "command -v litellm"
check 'check if litellm runs' bash -c "litellm --version"
reportResults
