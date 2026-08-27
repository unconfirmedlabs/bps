#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

# shellcheck disable=SC1091
source "${repo_root}/formal/toolchain.env"

if [[ $# -lt 1 ]]; then
    echo "usage: $0 IMAGE_REF [docker buildx build options...]" >&2
    exit 2
fi

image_ref="$1"
shift

docker buildx build \
    --platform linux/amd64 \
    --file "${repo_root}/docker/prover.Dockerfile" \
    --build-arg "RUST_IMAGE=${RUST_IMAGE}" \
    --build-arg "DOTNET_SDK_IMAGE=${DOTNET_SDK_IMAGE}" \
    --build-arg "DOTNET_RUNTIME_IMAGE=${DOTNET_RUNTIME_IMAGE}" \
    --build-arg "Z3_IMAGE=${Z3_IMAGE}" \
    --build-arg "SUI_PROVER_REPOSITORY=${SUI_PROVER_REPOSITORY}" \
    --build-arg "SUI_PROVER_REV=${SUI_PROVER_REV}" \
    --build-arg "SUI_PROVER_VERSION=${SUI_PROVER_VERSION}" \
    --build-arg "SUI_REPOSITORY=${SUI_REPOSITORY}" \
    --build-arg "SUI_REV=${SUI_REV}" \
    --build-arg "BOOGIE_VERSION=${BOOGIE_VERSION}" \
    --build-arg "Z3_VERSION=${Z3_VERSION}" \
    --build-arg "Z3_ARCHIVE=${Z3_ARCHIVE}" \
    --build-arg "Z3_URL=${Z3_URL}" \
    --build-arg "Z3_SHA256=${Z3_SHA256}" \
    --tag "${image_ref}" \
    "$@" \
    "${repo_root}"
