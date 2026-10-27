#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Matches scenarios.json and the controller in orianna's third_party/orchard; bump them together.
PINNED_VERSION=0.58.0

installs_the_pinned_version() {
	orchard --version | grep -qF "version ${PINNED_VERSION}"
}

check 'check if orchard exists' bash -c "command -v orchard"
check 'check if orchard installed the pinned version' installs_the_pinned_version
reportResults
