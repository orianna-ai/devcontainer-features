#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/litellm
# Matches scenarios.json; the option is an X.Y here, so the runtime is any patch of it.
REQUESTED_PYTHON=3.12

# Guards the option-to-runtime mapping: the launcher must run on the interpreter that was asked
# for, not on the default or on anything the image already had.
runs_on_the_requested_interpreter() {
	interpreter="$(head -n 1 "${INSTALL_PATH}/bin/litellm" | sed 's/^#!//')" || return 1
	case "$(readlink -f "${interpreter}")" in
	"${INSTALL_PATH}"/python/cpython-"${REQUESTED_PYTHON}".*) return 0 ;;
	*) return 1 ;;
	esac
}

reports_the_requested_python() {
	"$(head -n 1 "${INSTALL_PATH}/bin/litellm" | sed 's/^#!//')" --version | grep -qF "Python ${REQUESTED_PYTHON}."
}

check 'check if litellm exists' bash -c "command -v litellm"
check 'check if litellm runs' bash -c "litellm --version"
check 'check if litellm runs on the requested interpreter' runs_on_the_requested_interpreter
check 'check if the requested interpreter reports its version' reports_the_requested_python
reportResults
