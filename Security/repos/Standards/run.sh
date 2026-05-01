#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# run.sh — Security and Standards
#
# Scans all sibling projects for template compliance, security issues,
# and coding standards violations.
#
# Usage:
#   ./run.sh                # Full audit of all sibling projects
#   ./run.sh --no-recurse   # Audit this project only
#   ./run.sh --fix          # Auto-fix what can be fixed
# ─────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NO_RECURSE=false
FIX=false
for arg in "$@"; do
    case "$arg" in
        --no-recurse) NO_RECURSE=true ;;
        --fix)        FIX=true ;;
    esac
done

PROJECTS_ROOT="$(dirname "$SCRIPT_DIR")"
PASS=0
WARN=0
FAIL=0

step_pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
step_warn() { WARN=$((WARN + 1)); echo "  ⚠ $1"; }
step_fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    Security & Standards Audit        ║"
echo "╚══════════════════════════════════════╝"
echo ""

for proj_dir in "$PROJECTS_ROOT"/*/; do
    name=$(basename "$proj_dir")

    echo "▸ $name"

    # Template compliance: 4 entry scripts
    for script in run.sh setup.sh build.sh test.sh; do
        if [ -f "$proj_dir/$script" ]; then
            # Check executable permission
            if [ -x "$proj_dir/$script" ]; then
                step_pass "$script (exists, executable)"
            else
                step_warn "$script (exists, NOT executable)"
                if $FIX; then
                    chmod 700 "$proj_dir/$script"
                    echo "    → fixed permissions"
                fi
            fi
        else
            step_fail "$script MISSING"
        fi
    done

    # Codebase/ directory
    if [ -d "$proj_dir/Codebase" ]; then
        step_pass "Codebase/ directory"
    else
        step_warn "Codebase/ directory missing"
    fi

    # Git repo check
    if [ -d "$proj_dir/.git" ]; then
        remote=$(cd "$proj_dir" && git remote get-url origin 2>/dev/null || echo "")
        if [ -n "$remote" ]; then
            step_pass "Git repo with remote"
        else
            step_warn "Git repo but no remote configured"
        fi
    else
        step_warn "No git repository"
    fi

    # Security: check for secrets/credentials in tracked files
    if [ -d "$proj_dir/.git" ]; then
        SECRETS_FOUND=$(cd "$proj_dir" && git ls-files | grep -iE '\.env$|credentials|\.pem$|\.key$|password|secret.*\.json' 2>/dev/null | head -5)
        if [ -n "$SECRETS_FOUND" ]; then
            step_fail "Potential secrets in tracked files:"
            echo "$SECRETS_FOUND" | sed 's/^/      /'
        else
            step_pass "No obvious secrets in tracked files"
        fi
    fi

    # .gitignore check
    if [ -d "$proj_dir/.git" ]; then
        if [ -f "$proj_dir/.gitignore" ]; then
            step_pass ".gitignore present"
        else
            step_warn ".gitignore missing"
        fi
    fi

    echo ""
done

# Summary
TOTAL=$((PASS + WARN + FAIL))
echo "══════════════════════════════════════"
echo "  $PASS passed, $WARN warnings, $FAIL failures (of $TOTAL checks)"
echo "══════════════════════════════════════"
echo ""

if [ $FAIL -gt 0 ]; then
    exit 1
fi

# Recurse
if ! $NO_RECURSE && [ -d "Projects" ]; then
    for proj_dir in Projects/*/; do
        [ -f "$proj_dir/run.sh" ] && (cd "$proj_dir" && bash run.sh --no-recurse) &
    done
    wait
fi
