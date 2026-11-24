#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

PINNED_VERSION=4.94.1

installs_the_pinned_version() {
	fleetctl --version | grep -qF "version ${PINNED_VERSION}"
}

check 'check if fleetctl exists' bash -c "command -v fleetctl"
check 'check if fleetctl installed the pinned version' installs_the_pinned_version
reportResults
