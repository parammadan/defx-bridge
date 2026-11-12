#!/usr/bin/env bash
# DEFX Bridge interview demo. Runs offline; needs R + openxlsx (readxl optional).
# Usage: ./scripts/demo.sh            (pauses between steps)
#        DEMO_NO_PAUSE=1 ./scripts/demo.sh
set -u
cd "$(dirname "$0")/.."
BIN=./bin/defxbridge
OUT=artifacts
mkdir -p "$OUT"
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
pause() { [ "${DEMO_NO_PAUSE:-0}" = 1 ] || { printf '\n[enter to continue] '; read -r _; }; }
fail() { printf '\n\033[31mDEMO FAILED: %s\033[0m\n' "$1"; exit 1; }

step "1. A SAS program with DEFX tags (published syntax)"
grep -n "DEFX |" examples/valid/makeadae.sas | sed -n '1,4p;9,12p'
step "   ...and an R program using the same syntax as R comments"
grep -n "DEFX |" examples/valid/makeadsl.R | sed -n '1,3p;8,10p'
pause

step "2. scan: extract + normalize both languages, with file:line provenance"
$BIN scan --source examples/valid --spec examples/spec.csv --out "$OUT/scan.csv" || fail "scan"
pause

step "3. validate against the synthetic specification (expect PASSED, exit 0)"
$BIN validate --source examples/valid --spec examples/spec.csv --out "$OUT/validation.csv" || fail "validate"
pause

step "4. export into a COPY of the define-like template, then verify preservation"
$BIN export --source examples/valid --spec examples/spec.csv \
  --template examples/define_like_template.xlsx --out "$OUT/define_like_filled.xlsx" || fail "export"
pause

step "5. repeatability: export again from identical inputs and compare content"
$BIN export --source examples/valid --spec examples/spec.csv \
  --template examples/define_like_template.xlsx --out "$OUT/define_like_filled_rerun.xlsx" >/dev/null || fail "re-export"
$BIN compare "$OUT/define_like_filled.xlsx" "$OUT/define_like_filled_rerun.xlsx" || fail "outputs differ"
pause

step "6. deliberately invalid input: a tag naming a variable that is not in the spec (expect exit 2)"
cat examples/invalid/unknown_variable.R
expect_fail() {   # run a command that SHOULD fail validation with exit 2
  set +e; "$@"; local code=$?; set -e
  if [ "$code" -eq 2 ]; then
    printf "\033[32m-> expected: validation failed with exit code 2\033[0m\n"
  else
    fail "expected exit code 2, got $code"
  fi
}
set -e
expect_fail $BIN validate --source examples/invalid/unknown_variable.R --spec examples/spec.csv
pause

step "7. a genuine cross-program conflict (same target documented in a SAS and an R program)"
expect_fail $BIN validate --source examples/invalid/conflicting_definitions --spec examples/spec.csv
pause

step "8. the full invalid catalogue (malformed tags, bad types, predecessors, conflicts) -> CSV + report"
set +e
$BIN validate --source examples/invalid --spec examples/spec.csv --out "$OUT/invalid_validation.csv" | tail -1
code=${PIPESTATUS[0]}
set -e
[ "$code" -eq 2 ] || fail "invalid catalogue returned $code, expected 2"
printf "\033[32m-> expected: exit code 2; every diagnostic is in $OUT/invalid_validation.csv\033[0m\n"

step "Outputs"
for f in scan.csv validation.csv validation.md define_like_filled.xlsx define_like_filled_meta.csv \
         define_like_filled_report.md invalid_validation.csv invalid_validation.md; do
  [ -f "$OUT/$f" ] && printf '  %s\n' "$PWD/$OUT/$f"
done
printf '\nDemo complete.\n'
