#[test_only]
module bps::bps_tests;

use bps::bps::{Self, EOverflow, EUnderflow};

const U64_MAX: u64 = 18_446_744_073_709_551_615;
const U128_MAX: u128 = 340_282_366_920_938_463_463_374_607_431_768_211_455;

// === Constructors ===

#[test]
fun new_and_accessors() {
    let b = bps::new(250);
    assert!(b.value() == 250);
    assert!(!b.is_zero());
    assert!(!b.is_max());
}

#[test]
fun zero_and_max() {
    assert!(bps::zero().is_zero());
    assert!(bps::zero().value() == 0);
    assert!(bps::max().is_max());
    assert!(bps::max().value() == 10_000);
    assert!(bps::denominator!() == 10_000);
}

#[test]
fun from_percent_conversions() {
    assert!(bps::from_percent(0).value() == 0);
    assert!(bps::from_percent(5).value() == 500);
    assert!(bps::from_percent(50).value() == 5_000);
    assert!(bps::from_percent(100).value() == 10_000);
}

#[test, expected_failure(abort_code = EOverflow)]
fun new_above_max_aborts() {
    bps::new(10_001);
}

#[test, expected_failure(abort_code = EOverflow)]
fun from_percent_above_100_aborts() {
    bps::from_percent(101);
}

// === Apply (u64) ===

#[test]
fun apply_basic() {
    let b = bps::new(500); // 5%
    assert!(b.apply(1_000_000) == 50_000);
    assert!(b.apply(0) == 0);
    assert!(bps::zero().apply(1_000_000) == 0);
    assert!(bps::max().apply(1_000_000) == 1_000_000);
}

#[test]
fun apply_truncates_toward_zero() {
    // 100 * 33 / 10_000 = 0.33 → floor 0, ceil 1
    let b = bps::new(33);
    assert!(b.apply(100) == 0);
    assert!(b.apply_ceil(100) == 1);
}

#[test]
fun apply_ceil_matches_floor_on_exact_division() {
    let b = bps::new(500);
    assert!(b.apply(10_000) == 500);
    assert!(b.apply_ceil(10_000) == 500);
}

#[test]
fun apply_no_overflow_at_u64_limit() {
    // u64::MAX * 10_000 would overflow u64; mul_div widens internally.
    assert!(bps::max().apply(U64_MAX) == U64_MAX);
    // u64::MAX * 5000 / 10_000 = (u64::MAX - 1) / 2 = floor(u64::MAX/2)
    let half = U64_MAX / 2;
    assert!(bps::new(5_000).apply(U64_MAX) == half);
}

#[test]
fun split_invariant_exact() {
    let b = bps::new(2_500); // 25%
    let (taken, remainder) = b.split(1_000);
    assert!(taken == 250);
    assert!(remainder == 750);
    assert!(taken + remainder == 1_000);
}

#[test]
fun split_invariant_with_rounding_drift() {
    // 7 * 33% = 2.31 → taken = 2, remainder = 5. Sum must still equal input.
    let b = bps::new(3_300);
    let (taken, remainder) = b.split(7);
    assert!(taken == 2);
    assert!(remainder == 5);
    assert!(taken + remainder == 7);
}

#[test]
fun split_at_boundaries() {
    let (t, r) = bps::zero().split(1_000);
    assert!(t == 0 && r == 1_000);

    let (t, r) = bps::max().split(1_000);
    assert!(t == 1_000 && r == 0);
}

// === BPS composition ===

#[test]
fun add_and_sub() {
    let a = bps::new(3_000);
    let b = bps::new(2_000);
    assert!(a.add(b).value() == 5_000);
    assert!(a.sub(b).value() == 1_000);
}

#[test]
fun complement_roundtrip() {
    let b = bps::new(3_000);
    assert!(b.complement().value() == 7_000);
    assert!(b.complement().complement().value() == 3_000);
    assert!(bps::zero().complement().is_max());
    assert!(bps::max().complement().is_zero());
}

#[test]
fun apply_and_complement_partition_amount() {
    // floor(apply(b, x)) + floor(apply(complement(b), x)) may differ from x
    // by 1 due to double-flooring; that's why `split` exists. This test
    // documents the drift.
    let b = bps::new(3_333);
    let x = 100u64;
    let taken = b.apply(x);           // 33
    let other = b.complement().apply(x); // 66
    assert!(taken + other <= x);      // sum can be <= amount
    // split, in contrast, is exact:
    let (t, r) = b.split(x);
    assert!(t + r == x);
}

#[test, expected_failure(abort_code = EOverflow)]
fun add_overflow_aborts() {
    let a = bps::new(7_000);
    let b = bps::new(4_000);
    a.add(b);
}

#[test, expected_failure(abort_code = EUnderflow)]
fun sub_underflow_aborts() {
    let a = bps::new(1_000);
    let b = bps::new(2_000);
    a.sub(b);
}

// === u128 / u256 ===

#[test]
fun apply_u128_no_overflow_at_limit() {
    assert!(bps::max().apply_u128(U128_MAX) == U128_MAX);
}

#[test]
fun apply_u128_basic() {
    let b = bps::new(250); // 2.5%
    assert!(b.apply_u128(1_000_000_000u128) == 25_000_000u128);
}

#[test]
fun split_u128_invariant() {
    let b = bps::new(1_234);
    let (t, r) = b.split_u128(1_000_000_000u128);
    assert!(t + r == 1_000_000_000u128);
}

#[test]
fun apply_u256_basic() {
    let b = bps::from_percent(10);
    assert!(b.apply_u256(1_000u256) == 100u256);
}

// === u8 / u16 / u32 (supply-style amounts) ===

#[test]
fun apply_u16_nft_supply() {
    // "Reserve 500 bps (5%) of a 10_000-piece collection for team."
    let b = bps::new(500);
    assert!(b.apply_u16(10_000u16) == 500u16);
}

#[test]
fun apply_u16_no_overflow_at_limit() {
    // u16::MAX * 10_000 would overflow u16 without widening.
    assert!(bps::max().apply_u16(65_535u16) == 65_535u16);
}

#[test]
fun split_u16_invariant() {
    let b = bps::new(3_333);
    let (t, r) = b.split_u16(65_535u16);
    assert!(t + r == 65_535u16);
}

#[test]
fun apply_u32_large_supply() {
    // 1M-piece collection, burn 2%.
    let b = bps::from_percent(2);
    assert!(b.apply_u32(1_000_000u32) == 20_000u32);
}

#[test]
fun apply_u32_no_overflow_at_limit() {
    assert!(bps::max().apply_u32(4_294_967_295u32) == 4_294_967_295u32);
}

#[test]
fun apply_u8_basic() {
    // "100-piece ultra-limited, reserve 10%."
    let b = bps::from_percent(10);
    assert!(b.apply_u8(100u8) == 10u8);
}

#[test]
fun apply_u8_no_overflow_at_limit() {
    assert!(bps::max().apply_u8(255u8) == 255u8);
}

#[test]
fun apply_u8_ceil_rounds_up() {
    // 10 * 1 / 10_000 = 0.001 → floor 0, ceil 1
    let b = bps::new(1);
    assert!(b.apply_u8(10u8) == 0u8);
    assert!(b.apply_ceil_u8(10u8) == 1u8);
}

#[test]
fun split_u8_invariant_with_drift() {
    let b = bps::new(3_300);
    let (t, r) = b.split_u8(7u8);
    assert!(t + r == 7u8);
}
