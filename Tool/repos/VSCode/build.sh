#!/usr/bin/env bash
# =============================================================================
# build.sh — Build Go and C++ projects
#
# Usage:
#   ./build.sh          # Build everything
#   ./build.sh --go     # Build Go only
#   ./build.sh --cpp    # Build C++ only
#   ./build.sh --clean  # Clean build artifacts first
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()  { echo -e "${YELLOW}[BUILD]${NC} $*"; }
error() { echo -e "${RED}[BUILD]${NC} $*"; exit 1; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# -- Parse arguments -----------------------------------------------------------
BUILD_GO=false
BUILD_CPP=false
CLEAN=false

for arg in "$@"; do
    case $arg in
        --go)    BUILD_GO=true ;;
        --cpp)   BUILD_CPP=true ;;
        --clean) CLEAN=true ;;
        --help|-h)
            echo "Usage: ./build.sh [--go] [--cpp] [--clean]"
            exit 0
            ;;
        *) warn "Unknown argument: $arg (ignored)" ;;
    esac
done

# Default: build both
if [ "$BUILD_GO" = false ] && [ "$BUILD_CPP" = false ]; then
    BUILD_GO=true
    BUILD_CPP=true
fi

FAILURES=0

# =============================================================================
# Clean
# =============================================================================
if [ "$CLEAN" = true ]; then
    header "Cleaning Build Artifacts"
    rm -rf Codebase/go/bin Codebase/go/coverage
    rm -rf Codebase/cpp/build
    info "Clean complete"
fi

# =============================================================================
# Build Go
# =============================================================================
if [ "$BUILD_GO" = true ]; then
    header "Building Go"

    if [ ! -f Codebase/go/go.mod ]; then
        error "No go.mod found in Codebase/go/. Run setup first."
    fi

    cd Codebase/go
    mkdir -p bin

    info "Downloading dependencies..."
    go mod download

    info "Vetting code..."
    go vet ./... || { warn "go vet found issues"; FAILURES=$((FAILURES + 1)); }

    info "Compiling..."
    go build -race -o bin/ ./cmd/... 2>&1 || { warn "Go build failed"; FAILURES=$((FAILURES + 1)); }

    info "Go build complete — binaries in Codebase/go/bin/"
    cd "$SCRIPT_DIR"
fi

# =============================================================================
# Build C++
# =============================================================================
if [ "$BUILD_CPP" = true ]; then
    header "Building C++"

    if [ ! -f Codebase/cpp/CMakeLists.txt ]; then
        error "No CMakeLists.txt found in Codebase/cpp/. Run setup first."
    fi

    cd Codebase/cpp
    mkdir -p build
    cd build

    info "Configuring with CMake..."
    cmake -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DENABLE_TESTING=ON \
          -DENABLE_COVERAGE=ON \
          .. 2>&1 || { error "CMake configure failed"; }

    info "Compiling..."
    cmake --build . --parallel "$(nproc 2>/dev/null || echo 4)" 2>&1 || { warn "C++ build failed"; FAILURES=$((FAILURES + 1)); }

    # Copy compile_commands.json to project root for clangd
    if [ -f compile_commands.json ]; then
        cp compile_commands.json "$SCRIPT_DIR/Codebase/cpp/"
    fi

    info "C++ build complete — binaries in Codebase/cpp/build/"
    cd "$SCRIPT_DIR"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
if [ "$FAILURES" -gt 0 ]; then
    warn "Build finished with $FAILURES warning(s)"
    exit 1
else
    info "All builds succeeded"
fi
