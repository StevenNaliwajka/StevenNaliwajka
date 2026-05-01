#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
NO_RECURSE=false
for arg in "$@"; do case "$arg" in --no-recurse) NO_RECURSE=true ;; esac; done

echo "=== $(basename "$SCRIPT_DIR") Build ==="
echo "✓ No build targets configured"

if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/build.sh" ] && (cd "$proj_dir" && bash build.sh --no-recurse)
    done
fi
