# Security Audit — `bps`

**Package:** `bps` (`sources/bps.move` — single module, `bps::bps`)
**Audited revision:** `26e5ee2b0ad20ab9f03f51aa4f025843bbfd6d61` (`main`,
includes the "Harden BPS arithmetic and release verification" u256 totality
change; published to mainnet as `0xdb58d86a`)
**Audit date:** 2026-08-22
**Toolchain:** sui 1.77.2
**Framework reference:** Sui stdlib/framework sources cross-checked at pinned
revision `06734f6ff0af45d8632a14a4dc4b100197f6b1a2`

This document records an in-depth audit of `bps`, the basis-points math
library that underlies all royalty logic in the Miso ecosystem (protocol
composition/recording splits, release revenue distribution, and downstream
vault plugins). Its goal is to let a reader independently evaluate why the
library can be depended on as-is.

## What the library is

`BPS` is a `u16` newtype wrapping a value in basis points (10,000 = 100%).
The value field is private, so the core invariant — **value ≤ 10,000** — is
enforced by construction: `new` aborts (`EOverflow = 0`) above the bound,
`from_percent` and `add` preserve it, and `complement`/`sub` rely on it
(`sub` aborts `EUnderflow = 1`).

The API provides, per integer width (u8 / u16 / u32 / u64 / u128 / u256):

- `apply*` — floor-rounded `amount * bps / 10_000`
- `apply_ceil*` — ceiling-rounded variant
- `split` — exact partition: `taken + remainder == amount`

## Security properties, and why they hold

### Overflow is structurally impossible (u8–u128) and u256 is total

All `apply*` operations for u8 through u128 delegate to the stdlib's widening
`mul_div` (`std::macros::num_mul_div!`, verified at `macros.move:234–240` in
the pinned framework: `u64` computations are performed in `u128`, and so on).
Since `bps ≤ 10_000` is a type invariant, no input at these widths can
overflow — verified empirically at `u64::MAX` at 100%.

`apply_u256` (`bps.move:157`) uses quotient/remainder decomposition —
`amount = whole * denominator + remainder`, where both products are safe
because `rate ≤ denominator` and `remainder < denominator` — making it
**total over the entire u256 domain**: no input, including `u256::MAX`, can
abort. `apply_ceil_u256` (`bps.move:165`) reuses it via
`amount - complement.apply_u256(amount)`, so the ceiling path is total too.
Totality and rounding exactness at `u256::MAX` are pinned by dedicated tests
(`apply_u256_is_total_at_maximum`, `apply_ceil_u256_is_total_at_maximum`,
`split_u256_conserves_maximum`), and the fuzz suite draws from the full u256
domain. For scale: the largest amount in the ecosystem (miso_share's fixed
supply, 10¹³) is ~200× below even the *naive* non-widening u64 overflow
boundary.

### >100% is unrepresentable, not merely asserted

Because the value field is private and every constructor enforces the bound,
no caller can ever construct `BPS > 10_000`. `complement` can never
underflow. Division by zero is impossible (the denominator is a hardcoded
constant, and stdlib `mul_div` additionally asserts nonzero).

### Rounding is explicit and conservative

- `apply*` rounds **down** (floor): a recipient can never be paid more than
  their exact share — the correct default for royalty math.
- `apply_ceil*` rounds **up**, for callers that need the opposite policy.
- `split` is **exactly conserving**: `taken + remainder == amount` at every
  width, swept exhaustively (see Verification).

The composition of the two floor operations,
`apply(b, x) + apply(complement(b), x)`, is **exactly `x` or `x − 1`** —
never more, never less. This double-floor drift is now pinned as an enforced
test invariant (`complement_drift_is_at_most_one`), not just documented
behavior.

### Dust rounds to zero

`apply(b, x)` returns 0 when `x * bps < 10_000` (e.g. 1 bps of 9,999 units).
This is inherent to integer math and documented; every real caller in the
ecosystem handles the zero case explicitly (see Caller obligations). Callers
must never assume `apply(b, x) > 0` for nonzero `x`.

## Findings

No Critical, High, or Medium issues. The complete findings list:

| # | Severity | Item | Status |
|---|----------|------|--------|
| 1 | Info | Abort-code *values* were not pinned by tests (constants were referenced by name, so renumbering `0 ↔ 1` would pass the suite while breaking off-chain abort-code matchers) | **Fixed** — literal pins added (`bps_fuzz_tests.move`: `expected_failure(abort_code = 0/1)` tests) |
| 2 | Info | u256 arithmetic previously aborted with a VM `arithmetic_error` above `u256::MAX / 10_000` | **Resolved upstream** (`26e5ee2`): quotient/remainder decomposition makes u256 total — no abort path remains |
| 3 | Info | Three boundary branches untested (`apply_ceil(0)`, u256 boundary, floor/ceil sandwich at `u64::MAX`) | **Fixed** — covered by the upstreamed probe tests (`bps_audit_probes.move`) and fuzz suite |
| 4 | Low (usage risk, not a library bug) | Floor rounding means dust recipients receive 0 | Inherent; documented; all callers design around it |
| 5 | Info | `add`/`sub` use distinct abort codes (`EOverflow` vs `EUnderflow`) for one error class | Consistent and documented; no action |

## Caller obligations (downstream contract)

The library is safe *given its documented semantics*; these are the rules
callers must respect, verified against every real usage in the ecosystem:

1. **Construct only via `bps::new`/`from_percent`/`add`/`sub`** — the
   invariant depends on it. (`protocol/track.move:131,213`,
   `protocol/composition.move:152,265` comply.)
2. **Splits that must sum to 100% should be asserted as such** — e.g.
   `release.move:207` sums split values and asserts equality with the
   denominator. Correct pattern.
3. **Floor rounding leaves residuals.** Per-recipient `apply` sums to ≤ the
   total; the residual stays with the payer. Both real distribution flows
   rely on this correctly: `recording.move:238` (composition cut ≤ exact
   share, remainder stays with the recording creator) and
   `release_revenue_distributor.move:105` (per-track floor splits can never
   overdraw; the residual is explicitly returned to the Release address).
4. **`apply` may return 0 for nonzero input** (dust) — handle it; both
   callers above do.
5. **u256 callers** need no input bound: `apply_u256` / `apply_ceil_u256` are
   total over the full domain (since `26e5ee2`).

`misonetwork/royalty-pool` does not use this library and carries no
caller-semantics risk from it.

## Verification methodology

1. **Full line-by-line review** of `sources/bps.move` (169 lines), with
   stdlib widening behavior cross-checked against the pinned framework
   source rather than trusted from docs.
2. **74/74 unit tests passing**, comprising:
   - the original suite (48 tests as of `26e5ee2`, including upstream's u256
     totality and full-domain invariant tests),
   - 7 boundary probes (`bps_audit_probes.move`): naive-overflow boundary,
     u256 historical-boundary exactness, `apply_ceil(0)`, floor/ceil sandwich
     at `u64::MAX`, and related edges,
   - 19 fuzz/property tests (`bps_fuzz_tests.move`):
     **exhaustive** sweep of all 10,001 bps values × 9 representative
     amounts ({0, 1, 2, 9_999, 10_000, 10_001, 65_535, 10¹³, `u64::MAX`})
     asserting conservation, bounds, the floor/ceil sandwich, and endpoint
     exactness; deterministic xorshift64 PRNG fuzzing (fixed seed,
     reproducible) at all six widths — u256 drawn from the **full domain**,
     pinning totality — with forced boundary draws and a monotonicity check;
     the abort-code literal pins; and the exhaustive complement-drift
     invariant.
3. **Mutation testing** — 6 semantic mutations (denominator constant,
   div-before-mul reorder, boundary comparison flip, split remainder break,
   dropped ceil increment, removed widening) were each introduced into a
   scratch copy. **All 6 were killed by the original 44-test suite alone** —
   the shipped tests genuinely pin constants, rounding direction, overflow
   boundaries, and the conservation invariant. No surviving mutants.
4. **Caller-semantics review** of every downstream usage (see above).
5. **Lint hygiene** — `sui move build --lint` and `--lint --test` are
   warning-clean; README claims (rounding table, overflow behavior, abort
   table) verified accurate against actual behavior.

## Load-bearing external assumptions

- **Stdlib `mul_div` widening correctness** (`std::macros::num_mul_div!`):
  the no-overflow guarantee for u8–u128 rests on the stdlib computing in the
  next width up. Verified at the pinned revision; re-verify if building
  against a different framework version.
- **u256 native arithmetic**: the totality proof for `apply_u256` rests on
  checked u256 `*`/`/`/`%` semantics (abort on overflow/division-by-zero);
  the decomposition's operands are bounded so neither can trigger.

## Verdict

**Safe to depend on at rev `26e5ee2` as-is.** No exploitable findings; the
core invariant is type-enforced; overflow is structurally impossible at the
widths the ecosystem uses and the u256 path is total; rounding semantics are
explicit, conservative, and now invariant-pinned by an exhaustive-plus-fuzz
test suite that provably catches regressions (6/6 mutations killed).
