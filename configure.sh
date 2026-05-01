#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
# configure.sh — System-managed entry point.
#
# Delegates to .system/Configure canonical script.
# Project-specific logic lives in hooks/configure.sh.
#
# Do not edit — changes are overwritten on system sync.
# Source: git@github.com:Printect/Configure.git
# ─────────────────────────────────────────────────────────────────────

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

CONFIGURE_REMOTE="git@github.com:Printect/Configure.git"

_find_system() {
    local d="$SCRIPT_DIR"
    while [ "$d" != "/" ]; do
        [ -d "$d/.system/Configure/lib" ] && echo "$d/.system/Configure" && return
        d="$(dirname "$d")"
    done
}

SYS="$(_find_system)"

if [ -z "$SYS" ]; then
    mkdir -p "$SCRIPT_DIR/.system"
    git clone "$CONFIGURE_REMOTE" "$SCRIPT_DIR/.system/Configure" --quiet 2>/dev/null || true
    SYS="$SCRIPT_DIR/.system/Configure"
fi

export PROJECT_DIR="$SCRIPT_DIR"
exec bash "$SYS/scripts/$SCRIPT_NAME" "$@"
