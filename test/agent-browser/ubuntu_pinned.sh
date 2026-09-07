#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Matches scenarios.json; bump both together if this release is ever withdrawn.
PINNED_VERSION=0.35.0

installs_the_pinned_version() {
	agent-browser --version | grep -qF "${PINNED_VERSION}"
}

check 'check if agent-browser exists' bash -c "command -v agent-browser"
check 'check if agent-browser installed the pinned version' installs_the_pinned_version
reportResults
