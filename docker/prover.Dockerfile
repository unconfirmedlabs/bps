# syntax=docker/dockerfile:1.7

ARG RUST_IMAGE
ARG DOTNET_SDK_IMAGE
ARG DOTNET_RUNTIME_IMAGE
ARG Z3_IMAGE

FROM ${RUST_IMAGE} AS prover-builder

ARG SUI_PROVER_REPOSITORY
ARG SUI_PROVER_REV
ARG SUI_REV
ARG SUI_REPOSITORY

RUN git init /src/sui-prover \
    && git -C /src/sui-prover remote add origin "${SUI_PROVER_REPOSITORY}" \
    && git -C /src/sui-prover fetch --depth 1 origin "${SUI_PROVER_REV}" \
    && git -C /src/sui-prover checkout --detach FETCH_HEAD \
    && test "$(git -C /src/sui-prover rev-parse HEAD)" = "${SUI_PROVER_REV}"

WORKDIR /src/sui-prover
RUN cargo build --locked --release --bin sui-prover

# The runtime only needs the Move framework packages. Sparse checkout avoids
# copying the rest of the Sui monorepo into this build stage.
RUN git init /src/sui \
    && git -C /src/sui remote add origin "${SUI_REPOSITORY}" \
    && git -C /src/sui config core.sparseCheckout true \
    && git -C /src/sui sparse-checkout set crates/sui-framework/packages \
    && git -C /src/sui fetch --depth 1 --filter=blob:none origin "${SUI_REV}" \
    && git -C /src/sui checkout --detach FETCH_HEAD \
    && test "$(git -C /src/sui rev-parse HEAD)" = "${SUI_REV}"

FROM ${DOTNET_SDK_IMAGE} AS boogie-builder

ARG BOOGIE_VERSION
RUN dotnet tool install Boogie --version "${BOOGIE_VERSION}" --tool-path /opt/boogie \
    && /opt/boogie/boogie /version | grep -F "Boogie program verifier version ${BOOGIE_VERSION}"

FROM ${Z3_IMAGE} AS z3-builder

ARG Z3_ARCHIVE
ARG Z3_SHA256
ARG Z3_URL
ARG Z3_VERSION

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --silent --show-error "${Z3_URL}" --output "/tmp/${Z3_ARCHIVE}" \
    && echo "${Z3_SHA256}  /tmp/${Z3_ARCHIVE}" | sha256sum --check --strict \
    && unzip -q "/tmp/${Z3_ARCHIVE}" -d /tmp/z3 \
    && mv "/tmp/z3/z3-${Z3_VERSION}-x64-glibc-2.39" /opt/z3 \
    && /opt/z3/bin/z3 --version | grep -F "Z3 version ${Z3_VERSION}"

FROM ${DOTNET_RUNTIME_IMAGE} AS runtime

ARG BOOGIE_VERSION
ARG SUI_PROVER_REV
ARG SUI_PROVER_VERSION
ARG SUI_REV
ARG Z3_VERSION

LABEL org.opencontainers.image.title="BPS formal-verification toolchain" \
      org.opencontainers.image.description="Pinned Sui Prover, Boogie, Z3, and Sui framework for BPS proofs" \
      org.opencontainers.image.source="https://github.com/unconfirmedlabs/bps" \
      io.unconfirmedlabs.sui-prover.revision="${SUI_PROVER_REV}" \
      io.unconfirmedlabs.sui.revision="${SUI_REV}" \
      io.unconfirmedlabs.boogie.version="${BOOGIE_VERSION}" \
      io.unconfirmedlabs.z3.version="${Z3_VERSION}"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates coreutils diffutils libssl3 patch \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 prover \
    && useradd --create-home --uid 10001 --gid 10001 prover \
    && mkdir -p /opt/framework /workspace \
    && chown prover:prover /workspace

COPY --from=prover-builder /src/sui-prover/target/release/sui-prover /usr/local/bin/sui-prover
COPY --from=prover-builder /src/sui-prover/packages/prover /opt/framework/prover
COPY --from=prover-builder /src/sui-prover/packages/sui-specs /opt/framework/sui-specs
COPY --from=prover-builder /src/sui-prover/packages/sui-prover /opt/framework/sui-prover
COPY --from=prover-builder /src/sui/crates/sui-framework/packages/move-stdlib /opt/framework/move-stdlib
COPY --from=prover-builder /src/sui/crates/sui-framework/packages/sui-framework /opt/framework/sui-framework
COPY --from=prover-builder /src/sui/crates/sui-framework/packages/sui-system /opt/framework/sui-system
COPY --from=prover-builder /src/sui/crates/sui-framework/packages/deepbook /opt/framework/deepbook
COPY --from=boogie-builder /opt/boogie /opt/boogie
COPY --from=z3-builder /opt/z3 /opt/z3

# The upstream prover packages pin the same Sui revision in Cargo.lock but use
# the mutable `next` branch in Move.toml. Rewrite only those dependency entries
# to the exact framework packages copied above, making proof runs network-free.
RUN sed -i \
        's|MoveStdlib = { git = "https://github.com/asymptotic-code/sui.git", subdir = "crates/sui-framework/packages/move-stdlib", rev = "next", override = true }|MoveStdlib = { local = "../move-stdlib", override = true }|' \
        /opt/framework/prover/Move.toml \
    && sed -i \
        's|Sui = { git = "https://github.com/asymptotic-code/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "next", override = true }|Sui = { local = "../sui-framework", override = true }|' \
        /opt/framework/prover/Move.toml /opt/framework/sui-specs/Move.toml \
    && ! grep -R -E 'git[[:space:]]*=' /opt/framework/*/Move.toml

ENV BOOGIE_EXE=/opt/boogie/boogie \
    MOVE_HOME=/tmp/move-home \
    PATH=/opt/boogie:/opt/z3/bin:/usr/local/bin:/usr/bin:/bin \
    SUI_PROVER_FRAMEWORK_PATH=/opt/framework \
    Z3_EXE=/opt/z3/bin/z3

RUN sui-prover --version | grep -F "sui-prover ${SUI_PROVER_VERSION}" \
    && boogie /version | grep -F "Boogie program verifier version ${BOOGIE_VERSION}" \
    && z3 --version | grep -F "Z3 version ${Z3_VERSION}"

USER prover
WORKDIR /workspace

CMD ["sui-prover", "--version"]
