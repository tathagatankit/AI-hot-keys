#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../.."

for f in hammerspoon/rephrase/test/*_test.lua; do
  echo "=== $f ==="
  lua "$f"
done
