#!/bin/bash
set -e

# shellcheck source=/dev/null
source \
	dev-container-features-test-lib
check 'check if cloud-sql-proxy exists' bash -c 'which cloud-sql-proxy' | grep '/usr/bin/cloud-sql-proxy'
check 'check if cloud_sql_proxy exists' bash -c 'which cloud_sql_proxy' | grep '/usr/bin/cloud_sql_proxy'
reportResults
