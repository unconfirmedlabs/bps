/// Basis-points arithmetic with a newtype wrapper.
///
/// 1 bps = 0.01%. 10_000 bps = 100%.
///
/// Storage-optimal: `BPS` stores a `u16` (2 bytes), the tightest width that
/// fits the `[0, 10_000]` range. Apply functions cover every standard
/// integer width (`u8` through `u256`); overflow safety on `u8`–`u128` is
/// delegated to `std::uX::mul_div` / `mul_div_ceil`, which widen to the
/// next-larger type internally. `u256` has no wider type, so the
/// multiplication is performed directly and only overflows for amounts
/// exceeding `u256::MAX / 10_000` (~1.16e73).
module bps::bps;

// === Errors ===

const EOverflow: u64 = 0;
const EUnderflow: u64 = 1;

// === Constants ===

const DENOMINATOR: u16 = 10_000;

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

public fun value(b: BPS): u16 { b.0 }

public fun denominator(): u16 { DENOMINATOR }

public fun is_zero(b: BPS): bool { b.0 == 0 }

public fun is_max(b: BPS): bool { b.0 == DENOMINATOR }

// === Value composition ===

public fun add(a: BPS, b: BPS): BPS { new(a.0 + b.0) }

public fun sub(a: BPS, b: BPS): BPS {
    assert!(a.0 >= b.0, EUnderflow);
    BPS(a.0 - b.0)
}

public fun complement(b: BPS): BPS { BPS(DENOMINATOR - b.0) }

// === Apply to u8 ===

// DENOMINATOR does not fit in u8, so we widen to u16 for the arithmetic.
// Downcast is safe: `amount * bps / 10_000 <= amount <= u8::MAX`.

public fun apply_u8(b: BPS, amount: u8): u8 {
    (amount as u16).mul_div(b.0, DENOMINATOR) as u8
}

public fun apply_ceil_u8(b: BPS, amount: u8): u8 {
    (amount as u16).mul_div_ceil(b.0, DENOMINATOR) as u8
}

public fun split_u8(b: BPS, amount: u8): (u8, u8) {
    let taken = b.apply_u8(amount);
    (taken, amount - taken)
}

// === Apply to u16 ===

public fun apply_u16(b: BPS, amount: u16): u16 {
    amount.mul_div(b.0, DENOMINATOR)
}

public fun apply_ceil_u16(b: BPS, amount: u16): u16 {
    amount.mul_div_ceil(b.0, DENOMINATOR)
}

public fun split_u16(b: BPS, amount: u16): (u16, u16) {
    let taken = b.apply_u16(amount);
    (taken, amount - taken)
}

// === Apply to u32 ===

public fun apply_u32(b: BPS, amount: u32): u32 {
    amount.mul_div(b.0 as u32, DENOMINATOR as u32)
}

public fun apply_ceil_u32(b: BPS, amount: u32): u32 {
    amount.mul_div_ceil(b.0 as u32, DENOMINATOR as u32)
}

public fun split_u32(b: BPS, amount: u32): (u32, u32) {
    let taken = b.apply_u32(amount);
    (taken, amount - taken)
}

// === Apply to u64 ===

public fun apply(b: BPS, amount: u64): u64 {
    amount.mul_div(b.0 as u64, DENOMINATOR as u64)
}

public fun apply_ceil(b: BPS, amount: u64): u64 {
    amount.mul_div_ceil(b.0 as u64, DENOMINATOR as u64)
}

/// Splits `amount` by `b`. `taken + remainder == amount` always.
public fun split(b: BPS, amount: u64): (u64, u64) {
    let taken = b.apply(amount);
    (taken, amount - taken)
}

// === Apply to u128 ===

public fun apply_u128(b: BPS, amount: u128): u128 {
    amount.mul_div(b.0 as u128, DENOMINATOR as u128)
}

public fun apply_ceil_u128(b: BPS, amount: u128): u128 {
    amount.mul_div_ceil(b.0 as u128, DENOMINATOR as u128)
}

public fun split_u128(b: BPS, amount: u128): (u128, u128) {
    let taken = b.apply_u128(amount);
    (taken, amount - taken)
}

// === Apply to u256 ===

// u256 has no wider type to widen into, so the multiplication is performed
// directly. `b.0 <= 10_000`, so the multiply only overflows when
// `amount > u256::MAX / 10_000` (~1.16e73), well beyond any realistic value.
// Move's native overflow abort is the safety net.

public fun apply_u256(b: BPS, amount: u256): u256 {
    amount * (b.0 as u256) / (DENOMINATOR as u256)
}

public fun apply_ceil_u256(b: BPS, amount: u256): u256 {
    let numerator = amount * (b.0 as u256);
    let denominator = DENOMINATOR as u256;
    let q = numerator / denominator;
    if (numerator % denominator == 0) q else q + 1
}

public fun split_u256(b: BPS, amount: u256): (u256, u256) {
    let taken = b.apply_u256(amount);
    (taken, amount - taken)
}
