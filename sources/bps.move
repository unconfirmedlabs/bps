/// Basis-points arithmetic with a newtype wrapper.
///
/// 1 bps = 0.01%. 10_000 bps = 100%.
///
/// Storage-optimal: `BPS` stores a `u16` (2 bytes), the tightest width that
/// fits the `[0, 10_000]` range. Apply functions cover every standard
/// integer width (`u8` through `u256`). Arithmetic on `u8`–`u128` widens to
/// the next-larger type before multiplying. `u256` uses quotient/remainder
/// decomposition and is total over its entire input domain.
module bps::bps;

// === Errors ===

const EOverflow: u64 = 0;
const EUnderflow: u64 = 1;

// === Constants ===

const DENOMINATOR: u16 = 10_000;

// Expand widened arithmetic at each call site. This avoids both overflow and
// the runtime call into the standard integer helpers. The widened numerator
// has ample room for the extra 9_999 used by the ceiling formula.
macro fun mul_bps<$T, $U>($amount: $T, $rate: u16): $T {
    ((($amount as $U) * ($rate as $U)) / 10_000) as $T
}

macro fun mul_bps_ceil<$T, $U>($amount: $T, $rate: u16): $T {
    ((($amount as $U) * ($rate as $U) + 9_999) / 10_000) as $T
}

// === Struct ===

/// A basis-points value in `[0, 10_000]`.
public struct BPS(u16) has copy, drop, store;

// === Constructors ===

public fun new(v: u16): BPS {
    assert!(v <= DENOMINATOR, EOverflow);
    BPS(v)
}

public fun from_percent(pct: u8): BPS {
    assert!(pct <= 100, EOverflow);
    BPS((pct as u16) * 100)
}

public fun zero(): BPS { BPS(0) }

public fun max(): BPS { BPS(DENOMINATOR) }

// === Accessors ===

public fun value(b: BPS): u16 {
    let BPS(value) = b;
    value
}

public macro fun denominator(): u16 { 10_000 }

public fun is_zero(b: BPS): bool {
    let BPS(value) = b;
    value == 0
}

public fun is_max(b: BPS): bool {
    let BPS(value) = b;
    value == DENOMINATOR
}

// === Value composition ===

public fun add(a: BPS, b: BPS): BPS {
    let BPS(a) = a;
    let BPS(b) = b;
    let v = a + b;
    assert!(v <= DENOMINATOR, EOverflow);
    BPS(v)
}

public fun sub(a: BPS, b: BPS): BPS {
    let BPS(a) = a;
    let BPS(b) = b;
    assert!(a >= b, EUnderflow);
    BPS(a - b)
}

public fun complement(b: BPS): BPS {
    let BPS(value) = b;
    BPS(DENOMINATOR - value)
}

// === Apply to u8 ===

// Neither the rate nor its product with the amount fits in u8, so this path
// widens directly to u32. Downcast is safe because the result is <= amount.

public fun apply_u8(b: BPS, amount: u8): u8 {
    let BPS(rate) = b;
    mul_bps!<u8, u32>(amount, rate)
}

public fun apply_ceil_u8(b: BPS, amount: u8): u8 {
    let BPS(rate) = b;
    mul_bps_ceil!<u8, u32>(amount, rate)
}

public fun split_u8(b: BPS, amount: u8): (u8, u8) {
    let BPS(rate) = b;
    let taken = mul_bps!<u8, u32>(amount, rate);
    (taken, amount - taken)
}

// === Apply to u16 ===

public fun apply_u16(b: BPS, amount: u16): u16 {
    let BPS(rate) = b;
    mul_bps!<u16, u32>(amount, rate)
}

public fun apply_ceil_u16(b: BPS, amount: u16): u16 {
    let BPS(rate) = b;
    mul_bps_ceil!<u16, u32>(amount, rate)
}

public fun split_u16(b: BPS, amount: u16): (u16, u16) {
    let BPS(rate) = b;
    let taken = mul_bps!<u16, u32>(amount, rate);
    (taken, amount - taken)
}

// === Apply to u32 ===

public fun apply_u32(b: BPS, amount: u32): u32 {
    let BPS(rate) = b;
    mul_bps!<u32, u64>(amount, rate)
}

public fun apply_ceil_u32(b: BPS, amount: u32): u32 {
    let BPS(rate) = b;
    mul_bps_ceil!<u32, u64>(amount, rate)
}

public fun split_u32(b: BPS, amount: u32): (u32, u32) {
    let BPS(rate) = b;
    let taken = mul_bps!<u32, u64>(amount, rate);
    (taken, amount - taken)
}

// === Apply to u64 ===

public fun apply(b: BPS, amount: u64): u64 {
    let BPS(rate) = b;
    mul_bps!<u64, u128>(amount, rate)
}

public fun apply_ceil(b: BPS, amount: u64): u64 {
    let BPS(rate) = b;
    mul_bps_ceil!<u64, u128>(amount, rate)
}

/// Splits `amount` by `b`. `taken + remainder == amount` always.
public fun split(b: BPS, amount: u64): (u64, u64) {
    let BPS(rate) = b;
    let taken = mul_bps!<u64, u128>(amount, rate);
    (taken, amount - taken)
}

// === Apply to u128 ===

public fun apply_u128(b: BPS, amount: u128): u128 {
    let BPS(rate) = b;
    mul_bps!<u128, u256>(amount, rate)
}

public fun apply_ceil_u128(b: BPS, amount: u128): u128 {
    let BPS(rate) = b;
    mul_bps_ceil!<u128, u256>(amount, rate)
}

public fun split_u128(b: BPS, amount: u128): (u128, u128) {
    let BPS(rate) = b;
    let taken = mul_bps!<u128, u256>(amount, rate);
    (taken, amount - taken)
}

// === Apply to u256 ===

// u256 has no wider type to widen into. Decompose `amount` before multiplying:
//
//   amount = whole * denominator + remainder
//
// Both products are safe because `rate <= denominator` and
// `remainder < denominator`. Their sum is the exact floor of the requested
// ratio and cannot exceed `amount`.

public fun apply_u256(b: BPS, amount: u256): u256 {
    let BPS(rate) = b;
    let rate = rate as u256;
    let whole = amount / 10_000;
    let remainder = amount % 10_000;
    whole * rate + (remainder * rate) / 10_000
}

public fun apply_ceil_u256(b: BPS, amount: u256): u256 {
    let BPS(rate) = b;
    let rate = rate as u256;
    let whole = amount / 10_000;
    let remainder = amount % 10_000;
    whole * rate + (remainder * rate + 9_999) / 10_000
}

public fun split_u256(b: BPS, amount: u256): (u256, u256) {
    let BPS(rate) = b;
    let rate = rate as u256;
    let whole = amount / 10_000;
    let remainder = amount % 10_000;
    let taken = whole * rate + (remainder * rate) / 10_000;
    (taken, amount - taken)
}
