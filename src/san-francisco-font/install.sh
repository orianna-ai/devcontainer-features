#!/bin/bash
set -euo pipefail

MONO="${MONO:-true}"
WEB_SAFE_SANS="${WEBSAFESANS:-true}"
INSTALL_PATH="/usr/local/share/fonts/san-francisco"
CONFIG_NAME="59-san-francisco.conf"
CONFIG_PATH="/etc/fonts/conf.avail/${CONFIG_NAME}"
CONFIG_LINK="/etc/fonts/conf.d/${CONFIG_NAME}"
SF_PRO_URL="https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg"
SF_MONO_URL="https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg"

export DEBIAN_FRONTEND=noninteractive

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get was not found; this feature only supports debian and ubuntu base images" >&2
	exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the fonts from apple" >&2
	exit 1
fi

find_archiver() {
	local candidate
	for candidate in 7zz 7z 7za; do
		if command -v "${candidate}" >/dev/null 2>&1; then
			echo "${candidate}"
			return 0
		fi
	done
	return 1
}

apt-get update -y

if ! command -v fc-cache >/dev/null 2>&1; then
	apt-get install -y --no-install-recommends fontconfig
fi

archiver_package=""
if ! archiver="$(find_archiver)"; then
	if apt-cache show 7zip >/dev/null 2>&1; then
		archiver_package="7zip"
	else
		archiver_package="p7zip-full"
	fi

	apt-get install -y --no-install-recommends "${archiver_package}"

	if ! archiver="$(find_archiver)"; then
		echo "no 7-zip binary after installing ${archiver_package}" >&2
		exit 1
	fi
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

install_family() {
	local name="$1" url="$2"
	shift 2

	local work="${staging}/${name}"
	local package payload pattern font found
	local includes=()

	for pattern in "$@"; do
		includes+=("-ir!${pattern}")
	done

	mkdir -p "${work}"
	curl -fsSL "${url}" -o "${work}/font.dmg"
	"${archiver}" x -y -bso0 -bsp0 "${work}/font.dmg" -o"${work}/image"

	package="$(find "${work}/image" -name '*.pkg' -print -quit)"
	if [ -z "${package}" ]; then
		echo "no installer package inside ${url}; apple changed the download layout" >&2
		exit 1
	fi

	"${archiver}" x -y -bso0 -bsp0 "${package}" -o"${work}/package"

	payload="$(find "${work}/package" -name 'Payload*' -print -quit)"
	if [ -z "${payload}" ]; then
		echo "no payload inside ${package}; apple changed the download layout" >&2
		exit 1
	fi

	"${archiver}" x -y -bso0 -bsp0 "${payload}" -o"${work}/fonts" "${includes[@]}"

	for pattern in "$@"; do
		found=0

		while IFS= read -r font; do
			install -m 0644 "${font}" "${INSTALL_PATH}/"
			found=1
		done < <(find "${work}/fonts" -type f -name "${pattern}")

		if [ "${found}" -eq 0 ]; then
			echo "no font matching ${pattern} in ${url}; apple changed the font set" >&2
			exit 1
		fi
	done

	rm -rf "${work}"
}

prefer() {
	cat <<EOF
  <alias>
    <family>$1</family>
    <prefer><family>$2</family></prefer>
  </alias>
EOF
}

override() {
	cat <<EOF
  <match target="pattern">
    <test qual="any" name="family"><string>$1</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>$2</string></edit>
  </match>
EOF
}

rm -rf "${INSTALL_PATH}"
mkdir -p "${INSTALL_PATH}"

install_family pro "${SF_PRO_URL}" 'SF-Pro.ttf' 'SF-Pro-Italic.ttf'

if [ "${MONO}" = true ]; then
	install_family mono "${SF_MONO_URL}" 'SF-Mono-*.otf'
fi

mkdir -p "$(dirname "${CONFIG_PATH}")" "$(dirname "${CONFIG_LINK}")"

{
	echo '<?xml version="1.0"?>'
	echo '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
	echo '<fontconfig>'
	echo "  <dir>${INSTALL_PATH}</dir>"

	for family in system-ui -apple-system BlinkMacSystemFont .AppleSystemUIFont \
		'.SF NS' '.SF NS Text' '.SF NS Display' 'SF Pro Text' 'SF Pro Display'; do
		prefer "${family}" 'SF Pro'
	done

	prefer sans-serif 'SF Pro'

	if [ "${WEB_SAFE_SANS}" = true ]; then
		for family in Arial Helvetica 'Helvetica Neue' 'Segoe UI' Roboto; do
			override "${family}" 'SF Pro'
		done
	fi

	if [ "${MONO}" = true ]; then
		for family in monospace ui-monospace Menlo SFMono-Regular; do
			prefer "${family}" 'SF Mono'
		done
	fi

	echo '</fontconfig>'
} >"${CONFIG_PATH}"

chmod 0644 "${CONFIG_PATH}"
ln -sfn "${CONFIG_PATH}" "${CONFIG_LINK}"

fc-cache -f >/dev/null

if [ -n "${archiver_package}" ]; then
	apt-get purge -y "${archiver_package}" >/dev/null
fi

rm -rf /var/lib/apt/lists/*

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
