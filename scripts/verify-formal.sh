#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/formal-common.sh"

work_root="$(mktemp -d "${TMPDIR:-/tmp}/bps-formal.XXXXXX")"
trap 'rm -rf "${work_root}"' EXIT

harness="${work_root}/package"
prepare_formal_harness "${harness}"
run_formal_prover "${harness}" "$@"
