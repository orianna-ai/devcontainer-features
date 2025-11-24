#!/bin/bash
set -euo pipefail

deps=(curl ca-certificates)

missing_deps=()
for dep in "${deps[@]}"; do
	if ! dpkg -s "$dep" >/dev/null 2>&1; then
		missing_deps+=("$dep")
	fi
done

if ((${#missing_deps[@]} > 0)); then
	export DEBIAN_FRONTEND=noninteractive
	apt-get update
	apt-get install -y --no-install-recommends "${missing_deps[@]}"
	rm -rf /var/lib/apt/lists/*
fi

if [ "${VERSION:-"latest"}" = "latest" ]; then
	VERSION="$(
		wget -qO- https://api.github.com/repos/GoogleCloudPlatform/cloud-sql-proxy/releases/latest |
			grep "tag_name" |
			cut -d\" -f4 |
			sed 's/v//'
	)"
fi

case "$(uname -m)" in
x86_64)
	PLATFORM="amd64"
	;;
aarch64 | armv8*)
	PLATFORM="arm64"
	;;
*)
	echo "unsupported architecture"
	exit 1
	;;
esac

wget -qO /usr/local/bin/cloud-sql-proxy "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v${VERSION}/cloud-sql-proxy.linux.${PLATFORM}"
chmod +x /usr/local/bin/cloud-sql-proxy
ln -sf /usr/local/bin/cloud-sql-proxy /usr/local/bin/cloud_sql_proxy
