#!/bin/bash
set -euo pipefail

deps=(curl ca-certificates sudo)

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

curl -fsSL https://install.buildbuddy.io | bash
