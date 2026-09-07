#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
INSTALL_PATH="/usr/local/share/agent-browser"
REGISTRY="https://registry.npmjs.org/agent-browser"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the agent-browser package" >&2
	exit 1
fi

if ! command -v dpkg >/dev/null 2>&1; then
	echo "dpkg was not found; this feature only supports debian and ubuntu base images" >&2
	exit 1
fi

case "$(dpkg --print-architecture)" in
amd64) arch=x64 ;;
arm64) arch=arm64 ;;
*)
	echo "unsupported architecture $(dpkg --print-architecture); agent-browser ships linux builds for amd64 and arm64 only" >&2
	exit 1
	;;
esac

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

# The published package carries every platform's binary plus the skills, so one tarball answers
# both halves of the install. Only the members this platform needs are unpacked.
if ! curl -fsSL "${REGISTRY}/${VERSION}" -o "${staging}/metadata.json"; then
	echo "the registry has no agent-browser@${VERSION}" >&2
	exit 1
fi

tarball_url="$(tr ',' '\n' <"${staging}/metadata.json" | sed -n 's/.*"tarball":"\([^"]*\)".*/\1/p' | head -n1)"

if [ -z "${tarball_url}" ]; then
	echo "the registry returned no tarball for agent-browser@${VERSION}" >&2
	exit 1
fi

curl -fsSL "${tarball_url}" -o "${staging}/package.tgz"

binary_member="package/bin/agent-browser-linux-${arch}"

tar -xzf "${staging}/package.tgz" -C "${staging}" "${binary_member}" package/skill-data

if [ ! -s "${staging}/${binary_member}" ]; then
	echo "agent-browser@${VERSION} ships no ${binary_member}" >&2
	exit 1
fi

# The skills are the CLI's own guide to itself, and it only finds them through
# AGENT_BROWSER_SKILLS_DIR once the binary is lifted out of the package layout.
if [ ! -f "${staging}/package/skill-data/core/SKILL.md" ]; then
	echo "agent-browser@${VERSION} ships no skill-data/core/SKILL.md" >&2
	exit 1
fi

rm -rf "${INSTALL_PATH}"
install -D -m 0755 "${staging}/${binary_member}" "${INSTALL_PATH}/bin/agent-browser"
cp -R "${staging}/package/skill-data" "${INSTALL_PATH}/skill-data"

ln -sfn "${INSTALL_PATH}/bin/agent-browser" /usr/local/bin/agent-browser

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

# containerEnv is not in scope during the build, so the skills lookup is exercised the way the
# container will resolve it rather than trusting that the copy landed somewhere readable.
AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" --version
AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" skills path core >/dev/null
