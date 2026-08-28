#!/bin/bash
set -euo pipefail

MONO="${MONO:-true}"
WEB_SAFE_SANS="${WEBSAFESANS:-true}"

FONTS_PATH="/usr/local/share/fonts/san-francisco"
CONF_NAME="59-san-francisco.conf"
CONF_AVAIL="/etc/fonts/conf.avail/${CONF_NAME}"
CONF_ENABLED="/etc/fonts/conf.d/${CONF_NAME}"

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

apt_updated=false
apt_update() {
	if [ "${apt_updated}" = false ]; then
		apt-get update -y
		apt_updated=true
	fi
}

apt_install() {
	apt_update
	apt-get install -y --no-install-recommends "$@"
}

# fontconfig stays: fc-cache builds the cache the aliases below are read through, and fc-match is
# how anyone debugs them later. The archiver is a build-time dependency only, so it is purged again
# if this feature is what pulled it in.
if ! command -v fc-cache >/dev/null 2>&1; then
	apt_install fontconfig
fi

archiver_package=""
if ! archiver="$(find_archiver)"; then
	# Nothing else in the archive stack reads an HFS disk image and the xar package nested inside
	# it. 7zip is the package on trixie and noble onwards, p7zip-full on the releases before them.
	apt_update

	if apt-cache show 7zip >/dev/null 2>&1; then
		archiver_package="7zip"
	else
		archiver_package="p7zip-full"
	fi
	apt_install "${archiver_package}"

	if ! archiver="$(find_archiver)"; then
		echo "no 7-zip binary after installing ${archiver_package}" >&2
		exit 1
	fi
fi

staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

# Apple ships each family as a disk image holding an installer package, whose payload is a gzipped
# cpio archive of the fonts under ./Library/Fonts. 7-Zip reads all three layers, the payload's two
# in a single pass, and its include filters keep the payload from being unpacked in full -- SF Pro
# alone is 308MB of faces on disk against the 40MB this keeps.
#
# Every pattern has to match something. A download that no longer holds a face named here fails the
# build rather than producing an image whose fontconfig rules point at a family nobody installed.
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
			install -m 0644 "${font}" "${FONTS_PATH}/"
			found=1
		done < <(find "${work}/fonts" -type f -name "${pattern}")

		if [ "${found}" -eq 0 ]; then
			echo "no font matching ${pattern} in ${url}; apple changed the font set" >&2
			exit 1
		fi
	done

	rm -rf "${work}"
}

rm -rf "${FONTS_PATH}"
mkdir -p "${FONTS_PATH}"

# The variable fonts, not the 44 static instances beside them in the same download: one pair of
# files carries every weight and width, and its optical size axis is what makes text switch between
# the Text and Display designs by size the way it does on macOS.
install_family pro "${SF_PRO_URL}" 'SF-Pro.ttf' 'SF-Pro-Italic.ttf'

if [ "${MONO}" = true ]; then
	install_family mono "${SF_MONO_URL}" 'SF-Mono-*.otf'
fi

chown -R root:root "${FONTS_PATH}"
chmod -R a+rX,go-w "${FONTS_PATH}"

# Substitution, not renaming: the fonts keep their real family names, and these rules say which
# request each one answers. `prefer` inserts the family ahead of the requested name with a weak
# binding, so a page that names a font it actually has still gets that font.
prefer() {
	cat <<EOF
  <alias>
    <family>$1</family>
    <prefer><family>$2</family></prefer>
  </alias>
EOF
}

# For names fontconfig already substitutes -- Arial and Helvetica reach Liberation Sans through
# 30-metric-aliases.conf -- a weak preference loses to that strongly bound alias. These take the
# head of the family list with a binding of the same strength instead.
override() {
	cat <<EOF
  <match target="pattern">
    <test qual="any" name="family"><string>$1</string></test>
    <edit name="family" mode="prepend_first" binding="strong"><string>$2</string></edit>
  </match>
EOF
}

mkdir -p "$(dirname "${CONF_AVAIL}")" "$(dirname "${CONF_ENABLED}")"

{
	echo '<?xml version="1.0"?>'
	echo '<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">'
	echo '<fontconfig>'
	echo "  <dir>${FONTS_PATH}</dir>"

	# The names CSS and Apple's platforms use for "whatever the system font is".
	for family in system-ui -apple-system BlinkMacSystemFont .AppleSystemUIFont \
		'.SF NS' '.SF NS Text' '.SF NS Display' 'SF Pro Text' 'SF Pro Display'; do
		prefer "${family}" 'SF Pro'
	done

	# Ordering, not strength, is what beats 60-latin.conf: both preferences land in front of the
	# generic name, and the file read first ends up in front of the other. Hence the 59 prefix.
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
} >"${CONF_AVAIL}"

chmod 0644 "${CONF_AVAIL}"
ln -sfn "${CONF_AVAIL}" "${CONF_ENABLED}"

fc-cache -f >/dev/null

if [ -n "${archiver_package}" ]; then
	apt-get purge -y "${archiver_package}" >/dev/null
fi

if [ "${apt_updated}" = true ]; then
	rm -rf /var/lib/apt/lists/*
fi
