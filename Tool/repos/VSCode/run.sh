#!/usr/bin/env bash
# =============================================================================
# run.sh — Launch VSCode with the workspace, or run compiled binaries
#
# Usage:
#   ./run.sh              # Open VSCode with this workspace
#   ./run.sh --go         # Run the Go binary
#   ./run.sh --cpp        # Run the C++ binary
#   ./run.sh --build      # Build before running
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[RUN]${NC} $*"; }
warn()  { echo -e "${YELLOW}[RUN]${NC} $*"; }
error() { echo -e "${RED}[RUN]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# -- Parse arguments -----------------------------------------------------------
RUN_MODE="vscode"
BUILD_FIRST=false
EXTRA_ARGS=()

for arg in "$@"; do
    case $arg in
        --go)     RUN_MODE="go" ;;
        --cpp)    RUN_MODE="cpp" ;;
        --build)  BUILD_FIRST=true ;;
        --help|-h)
            echo "Usage: ./run.sh [--go] [--cpp] [--build]"
            echo "  (default)   Open VSCode with workspace"
            echo "  --go        Run the Go binary"
            echo "  --cpp       Run the C++ binary"
            echo "  --build     Build before running"
            exit 0
            ;;
        *) EXTRA_ARGS+=("$arg") ;;
    esac
done

# =============================================================================
# Build first if requested
# =============================================================================
if [ "$BUILD_FIRST" = true ]; then
    case "$RUN_MODE" in
        go)  bash "$SCRIPT_DIR/build.sh" --go ;;
        cpp) bash "$SCRIPT_DIR/build.sh" --cpp ;;
        *)   bash "$SCRIPT_DIR/build.sh" ;;
    esac
fi

# =============================================================================
# Run
# =============================================================================
case "$RUN_MODE" in
    vscode)
        if ! command -v code &>/dev/null; then
            error "VSCode CLI not found. Run ./setup.sh first."
        fi
        info "Opening VSCode workspace..."
        code "$SCRIPT_DIR" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
        ;;
    go)
        BINARY="$SCRIPT_DIR/Codebase/go/bin/app"
        if [ ! -f "$BINARY" ]; then
            error "Go binary not found. Run ./build.sh --go first."
        fi
        info "Running Go binary..."
        exec "$BINARY" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
        ;;
    cpp)
        BINARY="$SCRIPT_DIR/Codebase/cpp/build/app"
        if [ ! -f "$BINARY" ]; then
            error "C++ binary not found. Run ./build.sh --cpp first."
        fi
        info "Running C++ binary..."
        exec "$BINARY" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
        ;;
esac
