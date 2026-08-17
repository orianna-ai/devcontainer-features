#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Matches scenarios.json; bump both together if this build is ever withdrawn.
PINNED_VERSION=1.0.4

installs_the_pinned_version() {
	grok --version | grep -qF "${PINNED_VERSION}"
}

check 'check if grok exists' bash -c "command -v grok"
check 'check if grok installed the pinned version' installs_the_pinned_version
reportResults
