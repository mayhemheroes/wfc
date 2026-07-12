#!/usr/bin/env bash
#
# mayhem/build.sh — build the wfc fuzz harness, its standalone reproducer, and the
# upstream test suite.
#
#   /mayhem/fuzz_wfc             sanitized + libFuzzer -> target `wfc` (PNG -> wfc_overlapping -> wfc_run)
#   /mayhem/fuzz_wfc-standalone  sanitized, run-once reproducer (no libFuzzer runtime)
#   tests/test                   upstream suite (tests/test.c), NORMAL flags — run by mayhem/test.sh
#
# wfc is a single-header C library (wfc.h) using stb_image/stb_image_write; the stb
# headers are vendored at mayhem/vendor (upstream's Makefile fetches them from the
# network, which the air-gapped build forbids). No upstream edits.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}"
: "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "${SRC:-/mayhem}"

INC="-I. -Imayhem/vendor"

# 1) Fuzz harness (sanitized + instrumented; wfc.h/stb compile into the same TU, so the
#    whole fuzzed code path is instrumented). $DEBUG_FLAGS last so -gdwarf-3 wins (DWARF < 4).
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE $INC mayhem/fuzz_wfc.c -lm -o /mayhem/fuzz_wfc

# 2) Standalone run-once reproducer (same harness, LLVM's standalone driver, no libFuzzer).
# shellcheck disable=SC2086
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $INC "$STANDALONE_FUZZ_MAIN" mayhem/fuzz_wfc.c -lm -o /mayhem/fuzz_wfc-standalone

# 3) Upstream test suite (tests/test.c), NORMAL flags per upstream's `make test`
#    (cc tests/test.c -O2 -I. -o tests/test -lm) — mayhem/test.sh only RUNS it.
# shellcheck disable=SC2086
$CC -O2 $COVERAGE_FLAGS $INC tests/test.c -lm -o tests/test

echo "build.sh: built /mayhem/fuzz_wfc, /mayhem/fuzz_wfc-standalone, tests/test"
