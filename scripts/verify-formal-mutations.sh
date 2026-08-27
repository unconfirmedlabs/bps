#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${script_dir}/formal-common.sh"

mutations=(
    "floor-divisor.patch|bps_specs::apply_spec"
    "ceil-offset.patch|bps_specs::apply_ceil_spec"
    "u256-remainder.patch|bps_specs::apply_u256_spec"
    "split-conservation.patch|bps_specs::split_u256_spec"
)

for mutation in "${mutations[@]}"; do
    patch_name="${mutation%%|*}"
    target="${mutation#*|}"
    work_root="$(mktemp -d "${TMPDIR:-/tmp}/bps-mutation.XXXXXX")"
    harness="${work_root}/package"

    prepare_formal_harness "${harness}"
    # formal_repo_root is initialized by formal-common.sh above.
    # shellcheck disable=SC2154
    patch --batch --forward --directory "${harness}" --strip 1 \
        < "${formal_repo_root}/formal/mutations/${patch_name}"

    set +e
    output="$(PROVER_TIMEOUT_SECONDS="${MUTATION_TIMEOUT_SECONDS:-120}" \
        run_formal_prover "${harness}" --functions "${target}" 2>&1)"
    status=$?
    set -e

    rm -rf "${work_root}"

    if [[ ${status} -ne 1 ]]; then
        echo "mutation ${patch_name} produced exit ${status}; expected a verification failure (exit 1)" >&2
        echo "${output}" >&2
        exit 1
    fi

    if ! grep -Fq "exiting with verification errors" <<< "${output}"; then
        echo "mutation ${patch_name} failed for an unexpected reason" >&2
        echo "${output}" >&2
        exit 1
    fi

    echo "killed mutation: ${patch_name} (${target})"
done
