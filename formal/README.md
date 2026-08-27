# Formal verification

The checked-in Sui Prover suite proves the arithmetic contract of all 28 public
runtime functions, plus the source-only denominator macro and complement
involution. The proof targets exact floor and ceiling results, full-domain
overflow safety, bounded results, constructor/combinator behavior, and exact
split conservation.

## Reproduce

Build the pinned toolchain image:

```sh
source formal/toolchain.env
bash scripts/build-prover-image.sh \
  "bps-prover:${PROVER_IMAGE_TAG}" \
  --load
```

Run the complete proof without network access:

```sh
docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=4g \
  --volume "$PWD:/workspace:ro" \
  --workdir /workspace \
  "bps-prover:${PROVER_IMAGE_TAG}" \
  bash ./scripts/verify-formal.sh
```

Run the four negative controls:

```sh
docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=4g \
  --volume "$PWD:/workspace:ro" \
  --workdir /workspace \
  "bps-prover:${PROVER_IMAGE_TAG}" \
  bash ./scripts/verify-formal-mutations.sh
```

The scripts copy production `sources/bps.move` into a temporary package and
apply only `formal/patches/spec-value.patch`. That patch adds the spec-only
observer required to state properties over the private `BPS` field. A stale or
non-applicable patch fails before verification, preventing the proof harness
from silently drifting away from production.

## Toolchain and trust boundary

`formal/toolchain.env` pins the builder/runtime images, Asymptotic Sui Prover,
its Sui framework revision, Boogie, and the Z3 archive checksum. The image
rewrites the prover packages' mutable `next` dependencies to those exact local
framework copies. Proof jobs pin the published image by digest, mount the
repository read-only, and disable Docker networking.

The complete run proves 30 specification functions, which produce 90 backend
verification targets (`Check`, `Assume`, and `SpecNoAbortCheck`). CI also runs
the four mutation controls as an independent phase, so both phases must pass.

The proof establishes the checked-in specifications for the checked-in source.
It does not prove that the specifications cover every desired application-level
property, nor does it remove the Move compiler, Sui Prover translation, Boogie,
Z3, container base images, or package upgrade governance from the trusted
computing base.

The mutation controls deliberately introduce four arithmetic defects and
require the prover to return concrete verification failures. They guard against
vacuous specifications and broken CI wiring; they are not a substitute for
trusting the prover stack.
