#!/usr/bin/env bash
# setup.sh — Security and Standards
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NO_RECURSE=false
for arg in "$@"; do
    case "$arg" in --no-recurse) NO_RECURSE=true ;; esac
done

echo "=== Security and Standards Setup ==="

# Ensure scripts are executable
chmod 700 run.sh build.sh setup.sh test.sh 2>/dev/null || true
echo "✓ Scripts marked executable"

# Create Codebase structure
mkdir -p Codebase/{Models,Services,Utilities,Tests}
echo "✓ Codebase/ structure ready"

echo ""
echo "✓ Setup complete"
echo ""
echo "  Run an audit:  ./run.sh"
echo "  Run tests:     ./test.sh"
echo "  CI pipeline:   ./build.sh"

# Recurse
if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/setup.sh" ] && (cd "$proj_dir" && bash setup.sh --no-recurse)
    done
fi
