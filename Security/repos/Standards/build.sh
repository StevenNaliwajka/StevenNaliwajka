#!/usr/bin/env bash
# build.sh — Security and Standards
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NO_RECURSE=false
for arg in "$@"; do
    case "$arg" in --no-recurse) NO_RECURSE=true ;; esac
done

echo "=== Security and Standards Build ==="

echo "▸ Running full audit..."
bash run.sh --no-recurse
EXIT=$?

if [ $EXIT -eq 0 ]; then
    echo "✓ Build passed — all audits clean"
else
    echo "✗ Build failed — audit issues found"
fi

# Recurse
if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/build.sh" ] && (cd "$proj_dir" && bash build.sh --no-recurse)
    done
fi

exit $EXIT
