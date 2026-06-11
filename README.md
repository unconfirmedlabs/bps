# bps

Basis-points arithmetic for Sui Move, with a typed wrapper.

1 bps = 0.01%. 10,000 bps = 100%. A `BPS` is always in `[0, 10_000]` — every
constructor and combinator enforces the invariant, so any `BPS` you receive is
safe to apply without revalidating.

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
- `u8`–`u128` applications delegate to `std::uX::mul_div(_ceil)`, which widens
  to the next-larger type internally — they cannot overflow. `u256` has no wider
  type, so it multiplies directly and only aborts for amounts above
  `u256::MAX / 10_000` (~1.16e73).

## Aborts

| Code | Constant | When |
|---|---|---|
| 0 | `EOverflow` | `new` above 10,000, `from_percent` above 100, `add` past 100% |
| 1 | `EUnderflow` | `sub` below zero |
