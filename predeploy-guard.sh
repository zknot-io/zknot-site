#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -n "$(git status --porcelain)" ]; then
  echo "REFUSE: working tree dirty — this repo deploys the working directory."
  echo "Commit or stash before deploy. Uncommitted files ship silently."
  git status --porcelain
  exit 1
fi
echo "OK: clean tree at $(git rev-parse --short HEAD)"
