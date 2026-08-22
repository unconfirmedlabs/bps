# Security Audit — `bps`

**Revision:** `26e5ee2b0ad20ab9f03f51aa4f025843bbfd6d61` (`main`; mainnet
`0xdb58d86a`) · **Date:** 2026-08-22 · **Toolchain:** sui 1.77.2 ·
**Framework:** pinned rev `06734f6ff0af45d8632a14a4dc4b100197f6b1a2`

Audit of `bps`, the basis-points math library underlying all Miso royalty
logic. Verdict: **safe to depend on as-is — no Critical/High/Medium issues.**

## What it is

`BPS` is a `u16` newtype (10,000 = 100%). The value field is private and every
constructor enforces `value ≤ 10_000` (`new`/`add` abort `EOverflow = 0`,
`sub` aborts `EUnderflow = 1`), so >100% is unrepresentable and division by
zero is impossible. Per width (u8–u256): `apply*` (floor), `apply_ceil*`
(ceil), `split` (exact: `taken + remainder == amount`).

## Why it's safe

- **No overflow.** u8–u128 delegate to stdlib widening `mul_div` (u64
  computes in u128, etc.); with `bps ≤ 10_000` no input can overflow —
  probed at `u64::MAX`. `apply_u256` uses quotient/remainder decomposition
  and is **total**: no input, including `u256::MAX`, can abort.
- **Conservative rounding.** Floor never overpays a recipient; `split` is
  exactly conserving at every width; `apply(b,x) + apply(complement(b),x)`
  is pinned by test to exactly `x` or `x − 1` (never more).
- **Dust rounds to zero** — `apply` returns 0 when `amount * bps < 10_000`.
  Inherent to integer math; a design property, not a bug.

## Caller obligations

Verified against every real usage in the ecosystem; all callers comply:

1. Construct only via `new`/`from_percent`/`add`/`sub` — the invariant
   depends on it.
2. Splits meant to total 100% should be asserted against the denominator
   (pattern: `release.move`).
3. Floor leaves residuals — per-recipient `apply` sums to ≤ the total; the
   residual stays with the payer (both distribution flows rely on this).
4. `apply` may return 0 for nonzero input — handle the dust case.
5. u256 callers need no input bound (total since `26e5ee2`).

## Verification

- Line-by-line review; stdlib widening cross-checked against framework source.
- **74/74 tests passing**: the upstream suite (incl. u256 totality at
  `u256::MAX`), 7 audit boundary probes, 19 fuzz/property tests — exhaustive
  all-10,001-bps sweeps × 9 boundary amounts, deterministic xorshift64 fuzz
  at all six widths (u256 full-domain), abort-code literal pins.
- **Mutation testing: 6/6 killed** by the pre-existing suite (constant,
  rounding, boundary, conservation mutations) — the tests provably catch
  regressions.
- `build --lint --test` warning-clean; README verified accurate.

**Load-bearing assumption:** stdlib `mul_div` widening correctness (verified
at the pinned rev; re-verify on framework change).
