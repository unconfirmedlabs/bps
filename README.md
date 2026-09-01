# bps

Basis-points arithmetic for Sui Move, with a typed wrapper.

1 bps = 0.01%. 10,000 bps = 100%. A `BPS` is always in `[0, 10_000]` — every
constructor and combinator enforces the invariant, so any `BPS` you receive is
safe to apply without revalidating.

## Published packages

Both deployments are immutable.

| Network | Package ID | Transaction digest |
|---|---|---|
| Mainnet | `0xc470410a4790a5a4a5af09599e3ffb5b2ed47433e265ce6f19c7160ab9ebb266` | `GgPqdamuz398b72pERFKMy5ymU8P7Rad6wLP8CSJCX2D` |
| Testnet | `0xea4eda4f2120d8f7f726a5c558d0612a92f64d75197979de5902215bca0a5ef6` | `BD6DrFFsupQchhyj4btFRDZHNmpxhsvkCRMtkKcDaGG4` |

## Usage

```move
use bps::bps;

let fee = bps::new(250); // 2.5%

// Take a fee, keep the rest. Exact: taken + remainder == amount, always.
let (taken, remainder) = fee.split(amount);

// Or just compute the cut: floor by default, ceil when the protocol
// should round in its own favor.
let cut = fee.apply(amount);
let cut = fee.apply_ceil(amount);
```

## API

| Group | Functions |
|---|---|
| Constructors | `new(u16)`, `from_percent(u8)`, `zero()`, `max()` |
| Accessors | `value(): u16`, `is_zero()`, `is_max()`, `denominator!(): u16` |
| Composition | `add`, `sub`, `complement` |
| Application | `apply`, `apply_ceil`, `split` — unsuffixed for `u64`, plus `_u8`, `_u16`, `_u32`, `_u128`, `_u256` variants |

The unsuffixed functions take `u64` because `Coin`/`Balance` amounts are `u64`.

## Rounding semantics

- `apply*` floors (rounds toward zero); `apply_ceil*` rounds up.
- `split` guarantees `taken + remainder == amount` exactly, at every width.
  Computing `b.apply(x) + b.complement().apply(x)` instead can lose up to one
  unit to double flooring — use `split` when the parts must partition the whole.

## Design notes

- `BPS` stores a `u16` (2 bytes BCS), the tightest width that fits `[0, 10_000]`.
- `u8`–`u128` applications inline their arithmetic after widening to a safe
  larger type. Floor uses one multiplication and one division; ceil adds
  `9_999` before that division, avoiding a second remainder/division pass.
- The standard `mul_div` helpers are intentionally not used: they provide the
  same widening as ordinary function calls, and `mul_div_ceil` also performs a
  remainder check. The fixed 10,000 denominator permits the cheaper formulas.
- `u256` uses quotient/remainder decomposition, so every application width is
  total over its valid input domain without arithmetic overflow.
- All helpers are ordinary composable `public fun`s. The denominator is a
  source macro, so reading it adds neither a runtime call nor published
  bytecode.

## Development

Build and test both supported network environments explicitly:

```sh
sui move build --build-env testnet --lint --warnings-are-errors
sui move test --build-env testnet --lint --warnings-are-errors
sui move build --build-env mainnet --lint --warnings-are-errors
sui move test --build-env mainnet --lint --warnings-are-errors
```

`Move.lock` pins the framework revision and dependency graph separately for
Testnet and Mainnet and must be committed with release changes.

## Formal verification

The checked-in Sui Prover suite proves exact floor and ceiling arithmetic,
full-domain overflow safety, BPS bounds, constructor/combinator behavior, and
split conservation across every supported integer width. CI runs the proof in
a digest-pinned container with no network and a read-only repository, then
requires five deliberately incorrect implementations to fail verification.

See [`formal/README.md`](formal/README.md) for the proof boundary, exact
toolchain pins, mutation controls, and reproduction commands.

## Aborts

| Code | Constant | When |
|---|---|---|
| 0 | `EOverflow` | `new` above 10,000, `from_percent` above 100, `add` past 100% |
| 1 | `EUnderflow` | `sub` below zero |
