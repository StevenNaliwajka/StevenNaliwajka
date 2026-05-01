#!/usr/bin/env bash
# test.sh — Security and Standards
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NO_RECURSE=false
for arg in "$@"; do
    case "$arg" in --no-recurse) NO_RECURSE=true ;; esac
done

echo "=== Security and Standards Tests ==="

PASS=0
FAIL=0

# Test 1: Verify the audit script runs without crashing
echo "▸ Audit script execution"
if bash run.sh --no-recurse > /dev/null 2>&1; then
    echo "  ✓ Audit script runs cleanly"
    PASS=$((PASS + 1))
else
    echo "  ✗ Audit script failed"
    FAIL=$((FAIL + 1))
fi

# Test 2: Verify all sibling projects have entry scripts
echo "▸ Template compliance check"
PROJECTS_ROOT="$(dirname "$SCRIPT_DIR")"
MISSING=0
for proj_dir in "$PROJECTS_ROOT"/*/; do
    for script in run.sh setup.sh build.sh test.sh; do
        [ ! -f "$proj_dir/$script" ] && MISSING=$((MISSING + 1))
    done
done
if [ $MISSING -eq 0 ]; then
    echo "  ✓ All projects have all 4 entry scripts"
    PASS=$((PASS + 1))
else
    echo "  ✗ $MISSING missing entry scripts across projects"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"

# Recurse
if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/test.sh" ] && (cd "$proj_dir" && bash test.sh --no-recurse)
    done
fi

exit $FAIL
