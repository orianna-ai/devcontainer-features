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

tar -xzf "${staging}/package.tgz" -C "${staging}" package/skill-data

binary="${staging}/package/bin/agent-browser-linux-${arch}"

if ! tar -xzf "${staging}/package.tgz" -C "${staging}" "package/bin/agent-browser-linux-${arch}" 2>/dev/null; then
	resolved="${tarball_url##*/agent-browser-}"
	resolved="${resolved%.tgz}"
	native="cli-linux-${arch}-gnu"

	if ! curl -fsSL "${REGISTRY%/*}/@agent-browser/${native}/-/${native}-${resolved}.tgz" -o "${staging}/native.tgz"; then
		echo "the registry has no @agent-browser/${native}@${resolved}" >&2
		exit 1
	fi

	mkdir "${staging}/native"
	tar -xzf "${staging}/native.tgz" -C "${staging}/native" package/bin/agent-browser
	binary="${staging}/native/package/bin/agent-browser"
fi

if [ ! -s "${binary}" ]; then
	echo "agent-browser@${VERSION} ships no linux ${arch} binary" >&2
	exit 1
fi

if [ ! -f "${staging}/package/skill-data/core/SKILL.md" ]; then
	echo "agent-browser@${VERSION} ships no skill-data/core/SKILL.md" >&2
	exit 1
fi

rm -rf "${INSTALL_PATH}"
install -D -m 0755 "${binary}" "${INSTALL_PATH}/bin/agent-browser"
cp -R "${staging}/package/skill-data" "${INSTALL_PATH}/skill-data"

ln -sfn "${INSTALL_PATH}/bin/agent-browser" /usr/local/bin/agent-browser

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"

AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" --version
AGENT_BROWSER_SKILLS_DIR="${INSTALL_PATH}/skill-data" "${INSTALL_PATH}/bin/agent-browser" skills path core >/dev/null
