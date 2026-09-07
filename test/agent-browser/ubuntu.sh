#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib

INSTALL_PATH=/usr/local/share/agent-browser

resolves_inside_the_shared_prefix() {
	resolved="$(readlink -f "$(command -v agent-browser)")" || return 1
	test -x "${resolved}" || return 1
	case "${resolved}" in
	"${INSTALL_PATH}"/*) return 0 ;;
	*) return 1 ;;
	esac
}

# The binary's own lookup expects the npm package layout, so the skills only resolve through the
# variable -- and only if the copy behind it is readable by the remote user.
serves_the_bundled_skills() {
	test "${AGENT_BROWSER_SKILLS_DIR:-}" = "${INSTALL_PATH}/skill-data" &&
		test "$(agent-browser skills path core)" = "${INSTALL_PATH}/skill-data/core" &&
		agent-browser skills list | grep -q '^  core '
}

# Nothing about the CLI needs a node, so the scenario installs none and every check below runs
# against an image that has none.
no_node_on_path() {
	! command -v node >/dev/null 2>&1 &&
		! command -v npm >/dev/null 2>&1
}

not_writable_by_remote_user() {
	! test -w /usr/local/bin/agent-browser &&
		! test -w "${INSTALL_PATH}/bin/agent-browser" &&
		! test -w "${INSTALL_PATH}/skill-data/core/SKILL.md"
}

check 'check the image has no node of its own' no_node_on_path
check 'check if agent-browser exists' bash -c "command -v agent-browser"
check 'check if agent-browser runs' bash -c "agent-browser --version"
check 'check if agent-browser resolves inside the shared prefix' resolves_inside_the_shared_prefix
check 'check if agent-browser serves the bundled skills' serves_the_bundled_skills
check 'check if the shared install is read-only to the remote user' not_writable_by_remote_user
reportResults
