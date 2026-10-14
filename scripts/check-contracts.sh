#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
task_root=$(pwd)
task_compiler="${MARCH_COMPILER:-${HOME}/.march/current/bin/march}"
if [ ! -x "$task_compiler" ]; then
  task_compiler=$(command -v march)
fi
task_log=$(mktemp)
trap 'rm -f "$task_log"' EXIT HUP INT TERM
export MARCH_LIB_PATH="$task_root/lib"
check_rejected() {
  if "$task_compiler" --check "$1" > "$task_log" 2>&1; then
    echo "Expected rejection: $1" >&2
    exit 1
  fi
  if ! rg -q "$2" "$task_log"; then
    cat "$task_log" >&2
    exit 1
  fi
}
check_rejected fixtures/contracts/negative_precision.march refinement_violated
check_rejected fixtures/contracts/forged_asset.march unknown_constructor
echo "2 compile-time contract checks passed"
