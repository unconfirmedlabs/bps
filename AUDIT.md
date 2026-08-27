# Security, API, and Performance Audit — `bps`

**Base revision:** `d8a8591` · **Audit date:** 2026-08-27
**Local toolchain:** Sui 1.77.2 · **Pinned framework:**
`d50b78880fdacb1bbde92e6974ed71a7650c1090`

## Verdict

The optimized source has no unresolved correctness or API findings. Its public
surface and `BPS` layout are unchanged, every integer width is total over its
domain, and measured hot-path computation fell by 18–89% in the benchmarked
operations.

There is one deployment finding: the Mainnet and Testnet packages in
`Published.toml` contain the older code from commit `26fa571`. They do **not**
contain either the later full-domain `u256` hardening or the optimizations in
this working tree. An upgrade or new publish is required before on-chain
callers receive these changes.

## Public API audit

- One datatype: private-field `BPS(u16)` with only `copy`, `drop`, and `store`.
  It serializes to exactly two BCS bytes and cannot be constructed or read
  outside its defining module except through the public API.
- 28 public bytecode functions plus the source-only `denominator!` macro. There
  are no entry functions, objects, shared state, capabilities, events, or
  transfers.
- `BPS` is consistently the receiver/first parameter, all functions return
  their results, and every function is composable in a PTB or another module.
- The six width-specific apply/ceil/split families are necessary because Move
  has no generic arithmetic trait over primitive integer types. No additional
  aliases or wrappers are justified.
- Normalized pre/post package summaries are identical for every public
  signature, struct field, field order, type parameter, and ability. The two
  added arithmetic macros are private. This is a compatible upgrade surface.

The package is already published, so removing redundant-looking conveniences
such as `zero`, `max`, `is_zero`, or `is_max` would itself be an incompatible
API change. They are also cheap and useful enough that a breaking package
replacement would not be justified.

## Arithmetic audit

- Constructors and combinators preserve `0 <= BPS <= 10_000`; raw construction
  and positional-field access were independently confirmed to fail from a
  different module.
- `u8` through `u128` widen before multiplication. The widened product plus the
  `9_999` ceiling offset cannot approach the wider type's maximum, and the
  result is at most the input amount, so every downcast is safe.
- Floor expands to one widened multiplication and one division. Ceil uses
  `(amount * rate + 9_999) / 10_000`, avoiding the standard helper's remainder,
  branch, and second division.
- `u256` decomposes `amount = whole * 10_000 + remainder`; both partial
  products and their final sum are bounded. Ceil applies the same safe offset
  only to the small remainder product. Both paths are total at `u256::MAX`.
- `split*` computes the floor once and subtracts it from the original amount,
  so `taken + remainder == amount` exactly and cannot overflow.
- Abort codes remain pinned: `EOverflow = 0`, `EUnderflow = 1`.

## Computation results

Measurements used Sui 1.77.2, the pinned Testnet framework, one VM test thread,
and 10,000 identical calls per case. The table reports the metered delta after
removing the test runner's fixed base charge; loop overhead is identical, so
the percentages are conservative for the function bodies themselves.

| Hot path | Before | After | Reduction |
|---|---:|---:|---:|
| `value` | 7,102 | 5,792 | 18.4% |
| `add` + `sub` + `complement` + `value` | 243,464 | 155,414 | 36.2% |
| `apply` (`u64`) | 58,281 | 20,914 | 64.1% |
| `apply_ceil` (`u64`) | 165,381 | 23,034 | 86.1% |
| `apply_u128` | 66,283 | 23,223 | 65.0% |
| `apply_ceil_u128` | 237,387 | 27,244 | 88.5% |
| `apply_u256` | 224,340 | 132,308 | 41.0% |
| `apply_ceil_u256` | 316,438 | 136,328 | 56.9% |

The old `u8`–`u128` paths called `std::uX::mul_div` and
`std::uX::mul_div_ceil`. Both the pinned and current upstream implementations
are ordinary Move functions: floor expands to the same widened product and
quotient used here, while ceil goes through a remainder check and division.
There is no fused/native operation to recover by updating the dependency. The
standard helpers remain good general-purpose APIs, but this library's fixed
denominator and bounded rate permit a cheaper one-division ceiling formula.

Inlining lower-width floor arithmetic into `split*` reduced the already
optimized split path by a further 22.9% at `u64` and 18.0% at `u128`.
Inlining `split_u256` reduced that optimized path by a further 7.9%.

Two tempting alternatives were rejected by measurement:

- Reconstructing the `u256` remainder with multiply/subtract cost 15.5% more
  than `%` for floor.
- Reusing complement + floor for `u256` ceil cost 16.2% more than the direct
  remainder-ceiling formula.

The runtime optimization expands arithmetic at compile time. Testnet-addressed
module bytecode grew from 1,429 to 1,969 bytes (+37.8%), while immediate module
dependencies fell from four integer-helper modules to zero. This is a one-time
publish/storage tradeoff for recurring execution savings; the public API did
not grow.

## Verification

- 76/76 tests pass under both Testnet and Mainnet build environments with
  lints enabled and warnings treated as errors.
- Production-module instruction coverage is 100% (all 28 bytecode functions).
- Full deterministic boundary/property suite across `u8`, `u16`, `u32`,
  `u64`, `u128`, and full-domain `u256`.
- Exhaustive 10,001-rate sweeps at nine `u64` boundary amounts.
- Widened reference-result comparisons for every fuzzed `u8`–`u128` floor and
  ceiling result, plus independent `u256` identities and safe-product checks.
- Exact BCS-size regression and remainder-of-one ceiling regression.
- Four optimization-specific mutations (floor denominator, generic ceiling
  offset, `u256` ceiling offset, and split conservation) were all killed.
- Warning-clean linted builds and tests are required for both Testnet and
  Mainnet; see the commands in `README.md`.

## Published-bytecode finding

Using `sui client verify-source` with the recorded Sui 1.75.1 compiler:

- Mainnet `0xdb58d86a...1cfe0` exactly matches commit `26fa571`.
- Testnet `0x0f170226...59bff` also exactly matches the `26fa571` source when
  compiled at its recorded Testnet address.
- Both live packages expose the expected 28 functions and the same
  `BPS(u16)` layout, but their direct-multiplication `u256` implementation can
  overflow for sufficiently large inputs. The current source removes that
  limitation without changing the ABI.

Do not describe the deployed packages as full-domain `u256`-total until the
optimized source has been deployed and verified at the new package ID.

## Caller obligations

1. Use `split*` when two outputs must conserve the original amount exactly.
2. Expect floor to produce zero for dust and ceil to produce one for a nonzero
   fractional result.
3. Continue treating raw abort codes 0 and 1 as part of the integration
   contract.
4. Re-run source verification and gas measurements after changing the pinned
   framework or compiler.
