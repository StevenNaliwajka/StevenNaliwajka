#!/usr/bin/env bash
# =============================================================================
# setup.sh — Install VSCode, Go, C++ toolchains, and extensions
#
# Usage:
#   ./setup.sh              # Full setup
#   ./setup.sh --check      # Check what's installed without changing anything
#   ./setup.sh --extensions # Only install/update VSCode extensions
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[SETUP]${NC} $*"; }
warn()  { echo -e "${YELLOW}[SETUP]${NC} $*"; }
error() { echo -e "${RED}[SETUP]${NC} $*"; exit 1; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# -- Parse arguments -----------------------------------------------------------
MODE="full"
for arg in "$@"; do
    case $arg in
        --check)      MODE="check" ;;
        --extensions) MODE="extensions" ;;
        --help|-h)
            echo "Usage: ./setup.sh [--check] [--extensions]"
            echo "  --check       Check installed tools without making changes"
            echo "  --extensions  Only install/update VSCode extensions"
            exit 0
            ;;
        *) warn "Unknown argument: $arg (ignored)" ;;
    esac
done

# =============================================================================
# Detect OS
# =============================================================================
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &>/dev/null; then
            echo "debian"
        elif command -v dnf &>/dev/null; then
            echo "fedora"
        elif command -v pacman &>/dev/null; then
            echo "arch"
        else
            echo "linux-unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
info "Detected OS: $OS"

# =============================================================================
# Check mode — report what's installed
# =============================================================================
check_tool() {
    local name="$1"
    local cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" --version 2>/dev/null | head -1) || ver="(installed)"
        echo -e "  ${GREEN}✓${NC} $name: $ver"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name: not found"
        return 1
    fi
}

if [ "$MODE" = "check" ]; then
    header "Tool Check"
    echo ""
    echo "  IDE:"
    check_tool "VSCode" "code" || true
    echo ""
    echo "  Go Toolchain:"
    check_tool "Go" "go" || true
    check_tool "gopls" "gopls" || true
    check_tool "dlv (debugger)" "dlv" || true
    check_tool "staticcheck" "staticcheck" || true
    check_tool "golangci-lint" "golangci-lint" || true
    echo ""
    echo "  C++ Toolchain:"
    check_tool "GCC" "gcc" || true
    check_tool "G++" "g++" || true
    check_tool "Clang" "clang" || true
    check_tool "Clang++" "clang++" || true
    check_tool "CMake" "cmake" || true
    check_tool "Make" "make" || true
    check_tool "GDB" "gdb" || true
    check_tool "Valgrind" "valgrind" || true
    check_tool "cppcheck" "cppcheck" || true
    check_tool "clang-format" "clang-format" || true
    check_tool "clang-tidy" "clang-tidy" || true
    echo ""
    echo "  General:"
    check_tool "Git" "git" || true
    check_tool "pkg-config" "pkg-config" || true
    echo ""
    exit 0
fi

# =============================================================================
# Install VSCode
# =============================================================================
install_vscode() {
    if command -v code &>/dev/null; then
        info "VSCode already installed: $(code --version | head -1)"
        return 0
    fi

    header "Installing VSCode"
    case "$OS" in
        debian)
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/packages.microsoft.gpg
            sudo install -D -o root -g root -m 644 /tmp/packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
                sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
            sudo apt-get update -qq
            sudo apt-get install -y code
            rm -f /tmp/packages.microsoft.gpg
            ;;
        fedora)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | \
                sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
            sudo dnf install -y code
            ;;
        arch)
            if command -v yay &>/dev/null; then
                yay -S --noconfirm visual-studio-code-bin
            else
                error "Install yay or manually install 'visual-studio-code-bin' from AUR"
            fi
            ;;
        macos)
            if command -v brew &>/dev/null; then
                brew install --cask visual-studio-code
            else
                error "Install Homebrew first: https://brew.sh"
            fi
            ;;
        *) error "Unsupported OS for automatic VSCode install. Install manually." ;;
    esac
    info "VSCode installed successfully"
}

# =============================================================================
# Install Go toolchain
# =============================================================================
install_go() {
    header "Go Toolchain"

    if command -v go &>/dev/null; then
        info "Go already installed: $(go version)"
    else
        info "Installing Go..."
        case "$OS" in
            debian)  sudo apt-get install -y golang-go ;;
            fedora)  sudo dnf install -y golang ;;
            arch)    sudo pacman -S --noconfirm go ;;
            macos)   brew install go ;;
            *) error "Unsupported OS. Install Go manually from https://go.dev/dl/" ;;
        esac
    fi

    # Go tools for VSCode
    info "Installing Go development tools..."
    go install golang.org/x/tools/gopls@latest 2>/dev/null || warn "gopls install failed"
    go install github.com/go-delve/delve/cmd/dlv@latest 2>/dev/null || warn "dlv install failed"
    go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || warn "staticcheck install failed"
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest 2>/dev/null || warn "golangci-lint install failed"
    go install gotest.tools/gotestsum@latest 2>/dev/null || warn "gotestsum install failed"
    go install github.com/securego/gosec/v2/cmd/gosec@latest 2>/dev/null || warn "gosec install failed"
    go install golang.org/x/vuln/cmd/govulncheck@latest 2>/dev/null || warn "govulncheck install failed"

    info "Go toolchain ready"
}

# =============================================================================
# Install C++ toolchain
# =============================================================================
install_cpp() {
    header "C++ Toolchain"

    info "Installing C++ compilers and tools..."
    case "$OS" in
        debian)
            sudo apt-get install -y \
                build-essential \
                gcc g++ \
                clang clang-format clang-tidy \
                cmake \
                gdb \
                valgrind \
                cppcheck \
                pkg-config \
                libgtest-dev libgmock-dev \
                libbenchmark-dev \
                lcov
            ;;
        fedora)
            sudo dnf install -y \
                gcc gcc-c++ \
                clang clang-tools-extra \
                cmake make \
                gdb \
                valgrind \
                cppcheck \
                pkg-config \
                gtest-devel gmock-devel \
                google-benchmark-devel \
                lcov
            ;;
        arch)
            sudo pacman -S --noconfirm \
                base-devel \
                gcc clang \
                cmake \
                gdb \
                valgrind \
                cppcheck \
                gtest \
                benchmark \
                lcov
            ;;
        macos)
            xcode-select --install 2>/dev/null || true
            brew install cmake cppcheck valgrind googletest google-benchmark lcov
            ;;
        *) error "Unsupported OS for automatic C++ setup" ;;
    esac

    info "C++ toolchain ready"
}

# =============================================================================
# Install VSCode Extensions
# =============================================================================
install_extensions() {
    header "VSCode Extensions"

    if ! command -v code &>/dev/null; then
        warn "VSCode CLI not found — skipping extension install"
        return 1
    fi

    EXTENSIONS=(
        # Go
        "golang.go"

        # C/C++
        "ms-vscode.cpptools"
        "ms-vscode.cpptools-extension-pack"
        "ms-vscode.cmake-tools"
        "twxs.cmake"
        "jeff-hykin.better-cpp-syntax"

        # Testing
        "hbenl.vscode-test-explorer"
        "fredericbonnet.cmake-test-adapter"

        # General dev
        "eamodio.gitlens"
        "usernamehw.errorlens"
        "gruntfuggly.todo-tree"
        "streetsidesoftware.code-spell-checker"
        "EditorConfig.EditorConfig"
    )

    for ext in "${EXTENSIONS[@]}"; do
        info "Installing extension: $ext"
        code --install-extension "$ext" --force 2>/dev/null || warn "Failed to install $ext"
    done

    info "Extensions installed"
}

# =============================================================================
# Generate workspace settings
# =============================================================================
generate_settings() {
    header "Workspace Settings"

    mkdir -p "$SCRIPT_DIR/.vscode"

    cat > "$SCRIPT_DIR/.vscode/settings.json" << 'SETTINGS'
{
    "editor.formatOnSave": true,
    "editor.rulers": [100],
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,

    // Go
    "go.lintTool": "golangci-lint",
    "go.lintFlags": ["--fast"],
    "go.testFlags": ["-v", "-race", "-count=1"],
    "go.coverOnSave": true,
    "go.coverageDecorator": {
        "type": "gutter",
        "coveredHighlightColor": "rgba(64,128,64,0.2)",
        "uncoveredHighlightColor": "rgba(128,64,64,0.2)"
    },
    "gopls": {
        "ui.semanticTokens": true,
        "ui.diagnostic.analyses": {
            "shadow": true,
            "unusedparams": true,
            "unusedwrite": true
        }
    },

    // C++
    "C_Cpp.default.cppStandard": "c++20",
    "C_Cpp.default.cStandard": "c17",
    "C_Cpp.clang_format_fallbackStyle": "Google",
    "C_Cpp.codeAnalysis.clangTidy.enabled": true,
    "cmake.configureOnOpen": true,
    "cmake.buildDirectory": "${workspaceFolder}/Codebase/cpp/build",

    // Testing
    "testExplorer.useNativeTesting": true
}
SETTINGS

    cat > "$SCRIPT_DIR/.vscode/launch.json" << 'LAUNCH'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Go: Debug Current File",
            "type": "go",
            "request": "launch",
            "mode": "debug",
            "program": "${file}"
        },
        {
            "name": "Go: Debug Tests",
            "type": "go",
            "request": "launch",
            "mode": "test",
            "program": "${workspaceFolder}/Codebase/go/",
            "args": ["-v", "-race"]
        },
        {
            "name": "C++: Debug Active File",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/Codebase/cpp/build/${fileBasenameNoExtension}",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "gdb",
            "setupCommands": [
                { "text": "-enable-pretty-printing", "ignoreFailures": true }
            ],
            "preLaunchTask": "C++: Build Active File"
        },
        {
            "name": "C++: Debug Tests",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/Codebase/cpp/build/run_tests",
            "args": ["--gtest_color=yes"],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "MIMode": "gdb"
        }
    ]
}
LAUNCH

    cat > "$SCRIPT_DIR/.vscode/tasks.json" << 'TASKS'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Go: Build",
            "type": "shell",
            "command": "./build.sh --go",
            "group": "build",
            "problemMatcher": ["$go"]
        },
        {
            "label": "Go: Test",
            "type": "shell",
            "command": "./test.sh --go",
            "group": "test",
            "problemMatcher": ["$go"]
        },
        {
            "label": "C++: Build",
            "type": "shell",
            "command": "./build.sh --cpp",
            "group": "build",
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "C++: Build Active File",
            "type": "shell",
            "command": "cd Codebase/cpp && mkdir -p build && cd build && cmake .. && make ${fileBasenameNoExtension}",
            "group": "build",
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "C++: Test",
            "type": "shell",
            "command": "./test.sh --cpp",
            "group": "test",
            "problemMatcher": ["$gcc"]
        },
        {
            "label": "Full Build",
            "type": "shell",
            "command": "./build.sh",
            "group": { "kind": "build", "isDefault": true },
            "problemMatcher": ["$go", "$gcc"]
        },
        {
            "label": "Full Test",
            "type": "shell",
            "command": "./test.sh",
            "group": { "kind": "test", "isDefault": true },
            "problemMatcher": ["$go", "$gcc"]
        }
    ]
}
TASKS

    info "Workspace settings generated"
}

# =============================================================================
# Main
# =============================================================================
if [ "$MODE" = "extensions" ]; then
    install_extensions
    exit 0
fi

header "VSCode Go + C++ Development Setup"
echo ""

install_vscode
install_go
install_cpp
install_extensions
generate_settings

header "Setup Complete"
echo ""
echo "  Verify with:  ./setup.sh --check"
echo "  Build with:   ./build.sh"
echo "  Test with:    ./test.sh"
echo "  Run with:     ./run.sh"
echo ""
