#!/bin/bash
set -euo pipefail

# git
git config --global --add --bool push.autoSetupRemote true
git config --global --add safe.directory /workspaces/orianna

# devcontainers
npm install -g @devcontainers/cli

# pre-commit
pre-commit install --install-hooks
