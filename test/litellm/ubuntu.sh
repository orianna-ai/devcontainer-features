#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/litellm
# Matches the feature's default; bump both together when the reviewed release moves.
DEFAULT_VERSION=1.101.0

# Guards uv's own layout, which leaves the interpreter and launcher in a home directory.
resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v litellm)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

runs_on_the_private_interpreter() {
	interpreter="$(head -n 1 "${INSTALL_PATH}/bin/litellm" | sed 's/^#!//')" || return 1
	case "$(readlink -f "${interpreter}")" in
	"${INSTALL_PATH}"/python/*) return 0 ;;
	*) return 1 ;;
	esac
}

leaves_nothing_in_the_home_directory() {
	test ! -e "${HOME}/.local/bin/litellm" &&
		test ! -e "${HOME}/.local/share/uv" &&
		test ! -e "${HOME}/.cache/uv"
}

installs_the_reviewed_default_version() {
	litellm --version | grep -qF "${DEFAULT_VERSION}"
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/litellm &&
		! test -w "${INSTALL_PATH}/bin/litellm"
}

# The proxy's whole job is answering on a loopback port; a build that imports but cannot serve
# is not an install.
serves_its_liveliness_probe() {
	config="$(mktemp)"
	cat >"${config}" <<'YAML'
model_list:
  - model_name: "responses/*"
    litellm_params:
      model: "openai/*"
      api_base: http://127.0.0.1:9/v1
      api_key: unused
      use_chat_completions_api: true
general_settings:
  master_key: sk-test
YAML
	LITELLM_LOCAL_MODEL_COST_MAP=True litellm --config "${config}" --host 127.0.0.1 --port 4123 --telemetry False >/tmp/litellm.log 2>&1 &
	pid=$!
	ready=1
	for _ in $(seq 1 120); do
		if curl -sf http://127.0.0.1:4123/health/liveliness >/dev/null; then
			ready=0
			break
		fi
		sleep 1
	done
	kill "${pid}" 2>/dev/null || true
	wait "${pid}" 2>/dev/null || true
	test "${ready}" -eq 0 || cat /tmp/litellm.log >&2
	return "${ready}"
}

check 'check if litellm exists' bash -c "command -v litellm"
check 'check if litellm runs' bash -c "litellm --version"
check 'check if litellm resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if litellm runs on the private interpreter' runs_on_the_private_interpreter
check 'check if litellm installed the reviewed default version' installs_the_reviewed_default_version
check 'check if the installer left nothing in the home directory' leaves_nothing_in_the_home_directory
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
check 'check if litellm serves its liveliness probe' serves_its_liveliness_probe
reportResults
