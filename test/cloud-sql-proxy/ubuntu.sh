#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib
check 'check if cloud-sql-proxy exists' bash -c "command -v cloud-sql-proxy"
check 'check if cloud_sql_proxy exists' bash -c "command -v cloud_sql_proxy"
reportResults
