#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# The version pinned in scenarios.json. An exact version takes a different branch of install.sh
# than the default "latest" — it is passed to the upstream installer as a positional argument — so
# this covers the contract that branch depends on. Bump both if this build is ever withdrawn.
PINNED_VERSION=1.0.4

installs_the_pinned_version() {
	grok --version | grep -qF "${PINNED_VERSION}"
}

check 'check if grok exists' bash -c "command -v grok"
check 'check if grok installed the pinned version' installs_the_pinned_version
reportResults
