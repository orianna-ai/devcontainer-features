#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

# Matches scenarios.json; bump both together if this release is ever withdrawn.
PINNED_VERSION=1.101.0

installs_the_pinned_version() {
	litellm --version | grep -qF "${PINNED_VERSION}"
}

check 'check if litellm exists' bash -c "command -v litellm"
check 'check if litellm installed the pinned version' installs_the_pinned_version
reportResults
