#!/usr/bin/env bash
# =============================================================================
# test.sh — Heavy test suite for Go and C++ projects
#
# Runs unit tests, integration tests, race detection, fuzzing, benchmarks,
# static analysis, memory checks, and coverage reporting.
#
# Usage:
#   ./test.sh                # Run all tests (Go + C++)
#   ./test.sh --go           # Go tests only
#   ./test.sh --cpp          # C++ tests only
#   ./test.sh --quick        # Fast subset (unit tests, no benchmarks/fuzz)
#   ./test.sh --coverage     # Generate coverage reports
#   ./test.sh --bench        # Run benchmarks
#   ./test.sh --fuzz         # Run fuzz tests (30s per target)
#   ./test.sh --lint         # Static analysis only
#   ./test.sh --memcheck     # Valgrind memory checks (C++ only)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[TEST]${NC} $*"; }
warn()  { echo -e "${YELLOW}[TEST]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }
pass()  { echo -e "${GREEN}[PASS]${NC} $*"; }
header(){ echo -e "\n${CYAN}══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}══════════════════════════════════════════════${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# -- Parse arguments -----------------------------------------------------------
TEST_GO=false
TEST_CPP=false
RUN_QUICK=false
RUN_COVERAGE=false
RUN_BENCH=false
RUN_FUZZ=false
RUN_LINT=false
RUN_MEMCHECK=false
FUZZ_TIME="${FUZZ_TIME:-30s}"

for arg in "$@"; do
    case $arg in
        --go)       TEST_GO=true ;;
        --cpp)      TEST_CPP=true ;;
        --quick)    RUN_QUICK=true ;;
        --coverage) RUN_COVERAGE=true ;;
        --bench)    RUN_BENCH=true ;;
        --fuzz)     RUN_FUZZ=true ;;
        --lint)     RUN_LINT=true ;;
        --memcheck) RUN_MEMCHECK=true ;;
        --help|-h)
            echo "Usage: ./test.sh [--go] [--cpp] [--quick] [--coverage] [--bench] [--fuzz] [--lint] [--memcheck]"
            echo ""
            echo "  (default)     Run full test suite for both languages"
            echo "  --go          Go tests only"
            echo "  --cpp         C++ tests only"
            echo "  --quick       Unit tests only (skip benchmarks, fuzz, memcheck)"
            echo "  --coverage    Generate HTML coverage reports"
            echo "  --bench       Run benchmarks"
            echo "  --fuzz        Run fuzz tests (FUZZ_TIME env, default 30s)"
            echo "  --lint        Static analysis only"
            echo "  --memcheck    Valgrind memory checks (C++ only)"
            exit 0
            ;;
        *) warn "Unknown argument: $arg (ignored)" ;;
    esac
done

# Default: test both
if [ "$TEST_GO" = false ] && [ "$TEST_CPP" = false ]; then
    TEST_GO=true
    TEST_CPP=true
fi

# Full suite if no specific mode selected
if [ "$RUN_QUICK" = false ] && [ "$RUN_COVERAGE" = false ] && [ "$RUN_BENCH" = false ] && \
   [ "$RUN_FUZZ" = false ] && [ "$RUN_LINT" = false ] && [ "$RUN_MEMCHECK" = false ]; then
    RUN_COVERAGE=true
    RUN_BENCH=true
    RUN_FUZZ=true
    RUN_LINT=true
    if [ "$TEST_CPP" = true ]; then
        RUN_MEMCHECK=true
    fi
fi

# Quick mode overrides
if [ "$RUN_QUICK" = true ]; then
    RUN_BENCH=false
    RUN_FUZZ=false
    RUN_MEMCHECK=false
fi

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
RESULTS=()

record_result() {
    local name="$1" status="$2"
    if [ "$status" = "PASS" ]; then
        TOTAL_PASS=$((TOTAL_PASS + 1))
        RESULTS+=("${GREEN}  ✓ $name${NC}")
    elif [ "$status" = "FAIL" ]; then
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        RESULTS+=("${RED}  ✗ $name${NC}")
    else
        TOTAL_SKIP=$((TOTAL_SKIP + 1))
        RESULTS+=("${YELLOW}  ○ $name (skipped)${NC}")
    fi
}

# =============================================================================
# GO TESTS
# =============================================================================
if [ "$TEST_GO" = true ]; then
    header "Go Test Suite"

    if [ ! -f Codebase/go/go.mod ]; then
        warn "No Go project found — skipping"
        record_result "Go tests" "SKIP"
    else
        cd Codebase/go

        # ── Unit tests with race detector ──
        info "Running unit tests with race detector..."
        if go test -v -race -count=1 -timeout 120s ./... 2>&1; then
            pass "Go unit tests"
            record_result "Go unit tests + race detector" "PASS"
        else
            fail "Go unit tests"
            record_result "Go unit tests + race detector" "FAIL"
        fi

        # ── Test with short flag (ensures -short paths work) ──
        info "Running short tests..."
        if go test -short -count=1 ./... 2>&1; then
            pass "Go short tests"
            record_result "Go short tests" "PASS"
        else
            fail "Go short tests"
            record_result "Go short tests" "FAIL"
        fi

        # ── Coverage ──
        if [ "$RUN_COVERAGE" = true ]; then
            info "Generating Go coverage report..."
            mkdir -p coverage
            if go test -race -coverprofile=coverage/coverage.out -covermode=atomic ./... 2>&1; then
                go tool cover -html=coverage/coverage.out -o coverage/coverage.html 2>/dev/null || true
                go tool cover -func=coverage/coverage.out | tail -1
                pass "Go coverage"
                record_result "Go coverage report" "PASS"
            else
                fail "Go coverage"
                record_result "Go coverage report" "FAIL"
            fi
        fi

        # ── Benchmarks ──
        if [ "$RUN_BENCH" = true ]; then
            info "Running Go benchmarks..."
            if go test -bench=. -benchmem -benchtime=3s -run=^$ ./... 2>&1; then
                pass "Go benchmarks"
                record_result "Go benchmarks" "PASS"
            else
                fail "Go benchmarks"
                record_result "Go benchmarks" "FAIL"
            fi
        fi

        # ── Fuzz tests ──
        if [ "$RUN_FUZZ" = true ]; then
            info "Running Go fuzz tests (${FUZZ_TIME} per target)..."
            FUZZ_TARGETS=$(grep -r "func Fuzz" --include="*_test.go" -l . 2>/dev/null || true)
            if [ -n "$FUZZ_TARGETS" ]; then
                FUZZ_PASS=true
                for file in $FUZZ_TARGETS; do
                    pkg=$(dirname "$file")
                    funcs=$(grep -oP 'func (Fuzz\w+)' "$file" | awk '{print $2}')
                    for fn in $funcs; do
                        info "  Fuzzing $fn in $pkg..."
                        if ! go test -fuzz="^${fn}$" -fuzztime="$FUZZ_TIME" "$pkg" 2>&1; then
                            fail "  Fuzz $fn failed"
                            FUZZ_PASS=false
                        fi
                    done
                done
                if [ "$FUZZ_PASS" = true ]; then
                    record_result "Go fuzz tests" "PASS"
                else
                    record_result "Go fuzz tests" "FAIL"
                fi
            else
                warn "No fuzz targets found"
                record_result "Go fuzz tests" "SKIP"
            fi
        fi

        # ── Static analysis / linting ──
        if [ "$RUN_LINT" = true ]; then
            info "Running Go static analysis..."

            # go vet
            if go vet ./... 2>&1; then
                pass "go vet"
                record_result "Go vet" "PASS"
            else
                fail "go vet"
                record_result "Go vet" "FAIL"
            fi

            # staticcheck
            if command -v staticcheck &>/dev/null; then
                if staticcheck ./... 2>&1; then
                    pass "staticcheck"
                    record_result "Go staticcheck" "PASS"
                else
                    fail "staticcheck"
                    record_result "Go staticcheck" "FAIL"
                fi
            else
                record_result "Go staticcheck" "SKIP"
            fi

            # golangci-lint
            if command -v golangci-lint &>/dev/null; then
                if golangci-lint run --timeout 120s ./... 2>&1; then
                    pass "golangci-lint"
                    record_result "Go golangci-lint" "PASS"
                else
                    fail "golangci-lint"
                    record_result "Go golangci-lint" "FAIL"
                fi
            else
                record_result "Go golangci-lint" "SKIP"
            fi

            # govulncheck
            if command -v govulncheck &>/dev/null; then
                info "Running vulnerability check..."
                if govulncheck ./... 2>&1; then
                    pass "govulncheck"
                    record_result "Go vulnerability check" "PASS"
                else
                    fail "govulncheck"
                    record_result "Go vulnerability check" "FAIL"
                fi
            else
                record_result "Go vulnerability check" "SKIP"
            fi

            # gosec
            if command -v gosec &>/dev/null; then
                info "Running security scan..."
                if gosec -quiet ./... 2>&1; then
                    pass "gosec"
                    record_result "Go security scan (gosec)" "PASS"
                else
                    fail "gosec"
                    record_result "Go security scan (gosec)" "FAIL"
                fi
            else
                record_result "Go security scan (gosec)" "SKIP"
            fi
        fi

        cd "$SCRIPT_DIR"
    fi
fi

# =============================================================================
# C++ TESTS
# =============================================================================
if [ "$TEST_CPP" = true ]; then
    header "C++ Test Suite"

    if [ ! -f Codebase/cpp/CMakeLists.txt ]; then
        warn "No C++ project found — skipping"
        record_result "C++ tests" "SKIP"
    else
        cd Codebase/cpp

        # ── Build tests ──
        info "Building C++ tests..."
        mkdir -p build && cd build
        cmake -DCMAKE_BUILD_TYPE=Debug \
              -DENABLE_TESTING=ON \
              -DENABLE_COVERAGE=ON \
              -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
              .. 2>&1
        cmake --build . --parallel "$(nproc 2>/dev/null || echo 4)" 2>&1

        # ── Unit tests via CTest ──
        info "Running C++ unit tests (CTest)..."
        if ctest --output-on-failure --timeout 60 2>&1; then
            pass "C++ CTest"
            record_result "C++ unit tests (CTest)" "PASS"
        else
            fail "C++ CTest"
            record_result "C++ unit tests (CTest)" "FAIL"
        fi

        # ── GoogleTest direct run (verbose) ──
        if [ -f run_tests ]; then
            info "Running GoogleTest suite (verbose)..."
            if ./run_tests --gtest_color=yes --gtest_print_time=1 2>&1; then
                pass "GoogleTest"
                record_result "C++ GoogleTest suite" "PASS"
            else
                fail "GoogleTest"
                record_result "C++ GoogleTest suite" "FAIL"
            fi

            # ── GoogleTest with shuffle (detect order-dependent tests) ──
            info "Running GoogleTest with random shuffle..."
            if ./run_tests --gtest_shuffle --gtest_repeat=3 --gtest_color=yes 2>&1; then
                pass "GoogleTest shuffle"
                record_result "C++ test order independence (3x shuffle)" "PASS"
            else
                fail "GoogleTest shuffle"
                record_result "C++ test order independence (3x shuffle)" "FAIL"
            fi
        fi

        # ── Benchmarks ──
        if [ "$RUN_BENCH" = true ] && [ -f run_benchmarks ]; then
            info "Running C++ benchmarks..."
            if ./run_benchmarks --benchmark_color=true --benchmark_repetitions=3 2>&1; then
                pass "C++ benchmarks"
                record_result "C++ benchmarks (Google Benchmark)" "PASS"
            else
                fail "C++ benchmarks"
                record_result "C++ benchmarks (Google Benchmark)" "FAIL"
            fi
        fi

        # ── Coverage ──
        if [ "$RUN_COVERAGE" = true ]; then
            info "Generating C++ coverage report..."
            if command -v lcov &>/dev/null; then
                lcov --capture --directory . --output-file coverage.info --quiet 2>/dev/null || true
                lcov --remove coverage.info '/usr/*' '*/test/*' '*/googletest/*' \
                     --output-file coverage_filtered.info --quiet 2>/dev/null || true
                if command -v genhtml &>/dev/null && [ -f coverage_filtered.info ]; then
                    mkdir -p coverage_html
                    genhtml coverage_filtered.info --output-directory coverage_html --quiet 2>/dev/null || true
                    info "C++ coverage report: Codebase/cpp/build/coverage_html/index.html"
                fi
                if [ -f coverage_filtered.info ]; then
                    lcov --summary coverage_filtered.info 2>&1 || true
                    record_result "C++ coverage report" "PASS"
                else
                    record_result "C++ coverage report" "FAIL"
                fi
            else
                warn "lcov not installed — skipping coverage"
                record_result "C++ coverage report" "SKIP"
            fi
        fi

        # ── Valgrind memory check ──
        if [ "$RUN_MEMCHECK" = true ] && [ -f run_tests ]; then
            if command -v valgrind &>/dev/null; then
                info "Running Valgrind memory check..."
                if valgrind --leak-check=full \
                            --show-leak-kinds=all \
                            --track-origins=yes \
                            --error-exitcode=1 \
                            --suppressions=../valgrind.supp 2>/dev/null \
                            ./run_tests --gtest_color=yes 2>&1; then
                    pass "Valgrind memcheck"
                    record_result "C++ Valgrind memcheck" "PASS"
                else
                    # Try without suppressions file
                    if valgrind --leak-check=full \
                                --show-leak-kinds=all \
                                --track-origins=yes \
                                --error-exitcode=1 \
                                ./run_tests --gtest_color=yes 2>&1; then
                        pass "Valgrind memcheck"
                        record_result "C++ Valgrind memcheck" "PASS"
                    else
                        fail "Valgrind memcheck — memory leaks detected"
                        record_result "C++ Valgrind memcheck" "FAIL"
                    fi
                fi
            else
                warn "Valgrind not installed — skipping"
                record_result "C++ Valgrind memcheck" "SKIP"
            fi
        fi

        # ── AddressSanitizer build + run ──
        if [ "$RUN_QUICK" = false ]; then
            info "Building with AddressSanitizer..."
            cd "$SCRIPT_DIR/Codebase/cpp"
            mkdir -p build_asan && cd build_asan
            if cmake -DCMAKE_BUILD_TYPE=Debug \
                     -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" \
                     -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer -g" \
                     -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address" \
                     -DENABLE_TESTING=ON \
                     .. 2>&1 && \
               cmake --build . --parallel "$(nproc 2>/dev/null || echo 4)" 2>&1; then

                if [ -f run_tests ]; then
                    info "Running tests under AddressSanitizer..."
                    if ASAN_OPTIONS="detect_leaks=1:abort_on_error=1" ./run_tests --gtest_color=yes 2>&1; then
                        pass "AddressSanitizer"
                        record_result "C++ AddressSanitizer" "PASS"
                    else
                        fail "AddressSanitizer found issues"
                        record_result "C++ AddressSanitizer" "FAIL"
                    fi
                fi
            else
                warn "ASAN build failed"
                record_result "C++ AddressSanitizer" "FAIL"
            fi

            # Clean ASAN build
            cd "$SCRIPT_DIR"
            rm -rf Codebase/cpp/build_asan
        fi

        # ── ThreadSanitizer build + run ──
        if [ "$RUN_QUICK" = false ]; then
            info "Building with ThreadSanitizer..."
            cd "$SCRIPT_DIR/Codebase/cpp"
            mkdir -p build_tsan && cd build_tsan
            if cmake -DCMAKE_BUILD_TYPE=Debug \
                     -DCMAKE_CXX_FLAGS="-fsanitize=thread -g" \
                     -DCMAKE_C_FLAGS="-fsanitize=thread -g" \
                     -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=thread" \
                     -DENABLE_TESTING=ON \
                     .. 2>&1 && \
               cmake --build . --parallel "$(nproc 2>/dev/null || echo 4)" 2>&1; then

                if [ -f run_tests ]; then
                    info "Running tests under ThreadSanitizer..."
                    if ./run_tests --gtest_color=yes 2>&1; then
                        pass "ThreadSanitizer"
                        record_result "C++ ThreadSanitizer" "PASS"
                    else
                        fail "ThreadSanitizer found issues"
                        record_result "C++ ThreadSanitizer" "FAIL"
                    fi
                fi
            else
                warn "TSAN build failed"
                record_result "C++ ThreadSanitizer" "FAIL"
            fi

            # Clean TSAN build
            cd "$SCRIPT_DIR"
            rm -rf Codebase/cpp/build_tsan
        fi

        cd "$SCRIPT_DIR"

        # ── Static analysis ──
        if [ "$RUN_LINT" = true ]; then
            cd Codebase/cpp

            # cppcheck
            if command -v cppcheck &>/dev/null; then
                info "Running cppcheck..."
                if cppcheck --enable=all \
                            --suppress=missingIncludeSystem \
                            --error-exitcode=1 \
                            --inline-suppr \
                            --std=c++20 \
                            -I include/ \
                            src/ 2>&1; then
                    pass "cppcheck"
                    record_result "C++ cppcheck" "PASS"
                else
                    fail "cppcheck"
                    record_result "C++ cppcheck" "FAIL"
                fi
            else
                record_result "C++ cppcheck" "SKIP"
            fi

            # clang-tidy
            if command -v clang-tidy &>/dev/null; then
                info "Running clang-tidy..."
                CPP_FILES=$(find src/ -name '*.cpp' -o -name '*.cc' 2>/dev/null || true)
                if [ -n "$CPP_FILES" ]; then
                    TIDY_FAIL=false
                    for f in $CPP_FILES; do
                        if ! clang-tidy -p build/ "$f" -- -std=c++20 -I include/ 2>&1; then
                            TIDY_FAIL=true
                        fi
                    done
                    if [ "$TIDY_FAIL" = true ]; then
                        record_result "C++ clang-tidy" "FAIL"
                    else
                        pass "clang-tidy"
                        record_result "C++ clang-tidy" "PASS"
                    fi
                else
                    record_result "C++ clang-tidy" "SKIP"
                fi
            else
                record_result "C++ clang-tidy" "SKIP"
            fi

            # Format check
            if command -v clang-format &>/dev/null; then
                info "Checking C++ formatting..."
                FORMAT_FILES=$(find src/ include/ test/ -name '*.cpp' -o -name '*.h' -o -name '*.cc' -o -name '*.hpp' 2>/dev/null || true)
                if [ -n "$FORMAT_FILES" ]; then
                    if echo "$FORMAT_FILES" | xargs clang-format --dry-run --Werror 2>&1; then
                        pass "clang-format"
                        record_result "C++ format check (clang-format)" "PASS"
                    else
                        fail "clang-format — files need reformatting"
                        record_result "C++ format check (clang-format)" "FAIL"
                    fi
                else
                    record_result "C++ format check (clang-format)" "SKIP"
                fi
            else
                record_result "C++ format check (clang-format)" "SKIP"
            fi

            cd "$SCRIPT_DIR"
        fi
    fi
fi

# =============================================================================
# Summary
# =============================================================================
header "Test Results"
echo ""
for r in "${RESULTS[@]}"; do
    echo -e "$r"
done
echo ""
echo -e "${BOLD}  Total: $((TOTAL_PASS + TOTAL_FAIL + TOTAL_SKIP))  |  ${GREEN}Passed: $TOTAL_PASS${NC}  |  ${RED}Failed: $TOTAL_FAIL${NC}  |  ${YELLOW}Skipped: $TOTAL_SKIP${NC}"
echo ""

if [ "$TOTAL_FAIL" -gt 0 ]; then
    fail "Some tests failed"
    exit 1
else
    pass "All tests passed"
    exit 0
fi
