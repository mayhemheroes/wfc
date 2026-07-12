#!/usr/bin/env bash
#
# mayhem/test.sh — RUN wfc's upstream test suite (tests/test.c, built by mayhem/build.sh
# as tests/test). 13 tests: 10 unit tests (image ops, tile extraction, dedup) + 3
# integration tests (determinism, re-run, golden-image regression vs tests/reference/*.png).
# Behavioral oracle: the suite asserts exact pixel values, tile counts, and golden-output
# diffs — a no-op/exit(0) patch fails it.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "${SRC:-/mayhem}"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

if [ ! -x tests/test ]; then
  echo "tests/test missing — mayhem/build.sh should have built it" >&2
  emit_ctrf "wfc-tests" 0 1
  exit 1
fi

mkdir -p tests/output tests/reference   # upstream's `make test` pre-creates these
out=$(./tests/test 2>&1); rc=$?
echo "$out"

# Suite prints: "Results: <passed>/<run> passed[, <failed> FAILED]"
summary=$(echo "$out" | grep -Eo 'Results: [0-9]+/[0-9]+ passed' | tail -1)
if [ -z "$summary" ]; then
  echo "could not parse test suite results" >&2
  emit_ctrf "wfc-tests" 0 1
  exit 1
fi
passed=$(echo "$summary" | sed -E 's|Results: ([0-9]+)/([0-9]+) passed|\1|')
run=$(echo "$summary" | sed -E 's|Results: ([0-9]+)/([0-9]+) passed|\2|')
failed=$(( run - passed ))
[ "$rc" -ne 0 ] && [ "$failed" -eq 0 ] && failed=1

emit_ctrf "wfc-tests" "$passed" "$failed"
