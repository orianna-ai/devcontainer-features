#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-latest}"
TYPESCRIPT_VERSION="${TYPESCRIPTVERSION:-6}"
NODE_VERSION="${NODEVERSION:-24.18.0}"
INSTALL_PATH="/usr/local/share/typescript-language-server"
RUNTIME="/usr/local/share/node-runtime/v${NODE_VERSION}"
NODE="${RUNTIME}/bin/node"

if ! command -v curl >/dev/null 2>&1; then
	echo "curl was not found; it is needed to fetch the private node runtime" >&2
	exit 1
fi

# Install a private node runtime under its own root-owned prefix. The server must keep running when
# a workspace mutates the container's node however it likes — nvm/fnm/mise switches, uninstalls,
# even wiping the install — so it can never resolve its interpreter from PATH. Keyed by version so
# sibling features pinning the same NODE_VERSION share one copy without racing on contents.
install_node_runtime() {
	if [ -x "${NODE}" ]; then
		return
	fi

	local arch
	case "$(dpkg --print-architecture)" in
	amd64) arch=x64 ;;
	arm64) arch=arm64 ;;
	*)
		echo "unsupported architecture $(dpkg --print-architecture); node ships linux builds for amd64 and arm64 only" >&2
		exit 1
		;;
	esac

	local staging tarball
	staging="$(mktemp -d)"
	tarball="node-v${NODE_VERSION}-linux-${arch}.tar.gz"

	curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}" -o "${staging}/${tarball}"
	curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" -o "${staging}/SHASUMS256.txt"
	(cd "${staging}" && grep " ${tarball}\$" SHASUMS256.txt | sha256sum -c -)

	mkdir -p "${RUNTIME}"
	tar -xzf "${staging}/${tarball}" -C "${RUNTIME}" --strip-components=1
	rm -rf "${staging}"

	chown -R root:root "${RUNTIME}"
	chmod -R a+rX,go-w "${RUNTIME}"
}

# Run the private runtime's own npm, so the install works on images with no node at all. The
# runtime's bin dir is prepended to PATH for any lifecycle script npm spawns; the cache is kept out
# of the image.
npm() {
	env PATH="${RUNTIME}/bin:${PATH}" npm_config_cache="${npm_cache}" \
		"${NODE}" "${RUNTIME}/lib/node_modules/npm/bin/npm-cli.js" "$@"
}

install_node_runtime

npm_cache="$(mktemp -d)"
trap 'rm -rf "${npm_cache}"' EXIT

npm install --global --engine-strict --prefix "${INSTALL_PATH}" \
	"typescript-language-server@${VERSION}" \
	"typescript@${TYPESCRIPT_VERSION}"

if [ ! -f "${INSTALL_PATH}/lib/node_modules/typescript/lib/tsserver.js" ]; then
	echo "typescript@${TYPESCRIPT_VERSION} does not ship lib/tsserver.js, which typescript-language-server runs; use a version below 7" >&2
	exit 1
fi

# A wrapper rather than a symlink to the npm shim: the shim's `#!/usr/bin/env node` shebang would
# resolve the interpreter from the caller's PATH at spawn time, which is exactly the dependency
# this feature exists to remove. tsserver is spawned through fork(), which reuses this
# interpreter, so the whole server tree runs on the private runtime.
cat >/usr/local/bin/typescript-language-server <<EOF
#!/bin/sh
exec "${NODE}" "${INSTALL_PATH}/bin/typescript-language-server" "\$@"
EOF
chmod 0755 /usr/local/bin/typescript-language-server

chown -R root:root "${INSTALL_PATH}"
chmod -R a+rX,go-w "${INSTALL_PATH}"
