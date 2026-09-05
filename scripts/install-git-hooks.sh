#!/bin/sh
# Point git at the tracked hooks in .githooks/. Run once after cloning:
#   sh scripts/install-git-hooks.sh
set -e

cd "$(dirname "$0")/.."

# No repository (container image build, exported source tree): nothing to do.
[ -d .git ] || exit 0

chmod +x .githooks/* 2>/dev/null || true
git config core.hooksPath .githooks

echo "Git hooks installed from .githooks (core.hooksPath=.githooks)"
