#!/bin/bash
set -euo pipefail

if [ "${VERSION:-"latest"}" = "latest" ]; then
	VERSION="$(
		curl -s https://api.github.com/repos/GoogleCloudPlatform/cloud-sql-proxy/releases/latest |
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

curl -sSL "https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v${VERSION}/cloud-sql-proxy.linux.${PLATFORM}" -o /usr/local/bin/cloud-sql-proxy
chmod +x /usr/local/bin/cloud-sql-proxy
ln -sf /usr/local/bin/cloud-sql-proxy /usr/local/bin/cloud_sql_proxy
