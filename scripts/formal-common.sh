#!/usr/bin/env bash

formal_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
formal_repo_root="$(cd "${formal_script_dir}/.." && pwd)"

prepare_formal_harness() {
    local destination="$1"

    mkdir -p "${destination}/sources" "${destination}/specs"
    cp "${formal_repo_root}/Move.toml" "${destination}/Move.toml"
    cp "${formal_repo_root}/sources/bps.move" "${destination}/sources/bps.move"
    cp "${formal_repo_root}/formal/specs/Move.toml" "${destination}/specs/Move.toml"
    cp -R "${formal_repo_root}/formal/specs/sources" "${destination}/specs/sources"

    patch --batch --forward --directory "${destination}" --strip 1 \
        < "${formal_repo_root}/formal/patches/spec-value.patch"
}

run_formal_prover() {
    local harness="$1"
    shift

    local prover_move_home="${MOVE_HOME:-${harness}/move-home}"
    local prover_timeout="${PROVER_TIMEOUT_SECONDS:-300}"
    mkdir -p "${prover_move_home}"

    (
        cd "${harness}/specs" || exit 1
        MOVE_HOME="${prover_move_home}" sui-prover \
            --path . \
            --skip-fetch-latest-git-deps \
            --timeout "${prover_timeout}" \
            --force-timeout \
            --ci \
            "$@"
    )
}
