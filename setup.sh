#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# setup.sh — System-managed entry point.
#
# Bootstraps .system/Configure if missing, syncs it, then delegates
# to the canonical setup script. Project-specific logic in hooks/.
#
# Do not edit — changes are overwritten on system sync.
# Source: git@github.com:Printect/Configure.git
# ─────────────────────────────────────────────────────────────────────

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

CONFIGURE_REMOTE="git@github.com:Printect/Configure.git"

# ── Locate system Configure (walk up tree, then local) ──────────────
_find_system() {
    local d="$SCRIPT_DIR"
    while [ "$d" != "/" ]; do
        [ -d "$d/.system/Configure/lib" ] && echo "$d/.system/Configure" && return
        d="$(dirname "$d")"
    done
}

SYS="$(_find_system)"

# ── Bootstrap: clone if missing ─────────────────────────────────────
if [ -z "$SYS" ]; then
    echo "[System] Bootstrapping Configure..."
    mkdir -p "$SCRIPT_DIR/.system"
    if git clone "$CONFIGURE_REMOTE" "$SCRIPT_DIR/.system/Configure" --quiet 2>/dev/null; then
        echo "[System] Configure cloned"
    else
        echo "[System] Clone failed — using local .system/Configure"
    fi
    SYS="$SCRIPT_DIR/.system/Configure"
fi

# ── Sync: pull latest ───────────────────────────────────────────────
if [ -d "$SYS/.git" ]; then
    (cd "$SYS" && git pull --ff-only --quiet 2>/dev/null) || true
fi

# ── Delegate to canonical script ────────────────────────────────────
export PROJECT_DIR="$SCRIPT_DIR"
exec bash "$SYS/scripts/$SCRIPT_NAME" "$@"
