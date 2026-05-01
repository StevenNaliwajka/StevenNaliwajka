#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
NO_RECURSE=false
for arg in "$@"; do case "$arg" in --no-recurse) NO_RECURSE=true ;; esac; done

echo "=== $(basename "$SCRIPT_DIR") Setup ==="
chmod 700 run.sh build.sh setup.sh test.sh 2>/dev/null || true
echo "✓ Scripts marked executable"
echo "✓ Setup complete (no dependencies)"

if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/setup.sh" ] && (cd "$proj_dir" && bash setup.sh --no-recurse)
    done
fi
