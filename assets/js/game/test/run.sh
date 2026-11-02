#!/usr/bin/env bash
# Headless test-runner for The Hollow Ouroboros game logic (assets/js/game).
#
# Builds the game bundle once (proving it compiles), bundles each suite with
# esbuild for node, runs them, prints a summary, and exits non-zero on any
# failure. Run from anywhere:
#
#   assets/js/game/test/run.sh
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ESBUILD="$(cd "${ASSETS_DIR}/.." && pwd)/_build/esbuild-linux-x64"
OUTDIR="$(mktemp -d)"
trap 'rm -rf "${OUTDIR}"' EXIT

cd "${ASSETS_DIR}"

echo "== Building game bundle (compile check) =="
if ! "${ESBUILD}" js/game.js --bundle --target=es2022 --outdir="${OUTDIR}/bundle" \
    '--external:/fonts/*' '--external:/images/*' --external:phaser --alias:@=. ; then
  echo "BUNDLE BUILD FAILED"
  exit 1
fi

total_pass=0
total_fail=0
failed_suites=()

for suite in "${SCRIPT_DIR}"/*.mjs; do
  name="$(basename "${suite}" .mjs)"
  bundle="${OUTDIR}/${name}.cjs"
  if ! "${ESBUILD}" "${suite}" --bundle --platform=node --format=cjs --target=node20 \
      --outfile="${bundle}" --external:phaser ; then
    echo "  FAIL ${name} (esbuild bundle error)"
    total_fail=$((total_fail + 1))
    failed_suites+=("${name}")
    continue
  fi
  output="$(node "${bundle}" 2>&1)"
  summary="$(echo "${output}" | tail -1)"
  if echo "${summary}" | grep -qE ' 0 failed$' && [ "${PIPESTATUS[0]}" = 0 ]; then
    p="$(echo "${summary}" | sed -E 's/([0-9]+) passed.*/\1/')"
    total_pass=$((total_pass + p))
    echo "  ok   ${name}: ${summary}"
  else
    echo "${output}" | grep -E 'FAIL|Error' | head -10
    f="$(echo "${summary}" | sed -E 's/.* ([0-9]+) failed/\1/')"
    p="$(echo "${summary}" | sed -E 's/([0-9]+) passed.*/\1/')"
    total_pass=$((total_pass + ${p:-0}))
    total_fail=$((total_fail + ${f:-1}))
    failed_suites+=("${name}")
  fi
done

echo
echo "== Summary: ${total_pass} passed, ${total_fail} failed =="
if [ "${#failed_suites[@]}" -gt 0 ]; then
  echo "Failed suites: ${failed_suites[*]}"
  exit 1
fi
echo "All suites green."
