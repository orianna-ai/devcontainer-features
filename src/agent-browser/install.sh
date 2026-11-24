#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
INSTALL_PATH="/usr/local/share/agent-browser"
REGISTRY="https://registry.npmjs.org"

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

fetch_package() {
	local package="$1" version="$2" name="$3" tarball_url

	if ! curl -fsSL "${REGISTRY}/${package}/${version}" -o "${staging}/${name}.json"; then
		echo "the registry has no ${package}@${version}" >&2
		exit 1
	fi

	tarball_url="$(tr ',' '\n' <"${staging}/${name}.json" | sed -n 's/.*"tarball":"\([^"]*\)".*/\1/p' | head -n1)"

	if [ -z "${tarball_url}" ]; then
		echo "the registry returned no tarball for ${package}@${version}" >&2
		exit 1
	fi

	curl -fsSL "${tarball_url}" -o "${staging}/${name}.tgz"
	mkdir -p "${staging}/${name}"
	tar -xzf "${staging}/${name}.tgz" -C "${staging}/${name}"
}

fetch_package agent-browser "${VERSION}" main

resolved_version="$(sed -n 's/^  "version": "\([^"]*\)",\{0,1\}$/\1/p' "${staging}/main/package/package.json" | head -n1)"

if [ -z "${resolved_version}" ]; then
	echo "agent-browser@${VERSION} ships no version in its package.json" >&2
	exit 1
fi

binary="${staging}/main/package/bin/agent-browser-linux-${arch}"

if [ ! -e "${binary}" ]; then
	native_package="@agent-browser/cli-linux-${arch}-gnu"
	fetch_package "${native_package}" "${resolved_version}" native
	binary="${staging}/native/package/bin/agent-browser"
fi

if [ ! -s "${binary}" ]; then
	echo "agent-browser@${resolved_version} ships no linux ${arch} binary" >&2
	exit 1
fi

if [ ! -f "${staging}/main/package/skill-data/core/SKILL.md" ]; then
	echo "agent-browser@${resolved_version} ships no skill-data/core/SKILL.md" >&2
	exit 1
fi

rm -rf "${INSTALL_PATH}"
install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/agent-browser"
cp -R "${staging}/main/package/skill-data" "${INSTALL_PATH}/skill-data"

ln -sfn "${INSTALL_PATH}/bin/agent-browser" /usr/local/bin/agent-browser

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" --version
AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" skills path core >/dev/null
