#[test_only]
module bps::bps_audit_probes;

use bps::bps;

const U64_MAX: u64 = 18_446_744_073_709_551_615;

// Dust: nonzero (amount, bps) can floor to zero; ceil never does.
#[test]
fun probe_dust_to_zero() {
    // 1 bps of 9_999 = 0.9999 -> 0
    assert!(bps::new(1).apply(9_999) == 0);
    assert!(bps::new(1).apply_ceil(9_999) == 1);
    // smallest amount producing nonzero at 1 bps is exactly 10_000
    assert!(bps::new(1).apply(10_000) == 1);
    // bps = 10_000, amount = 0 -> 0, ceil also 0
    assert!(bps::max().apply(0) == 0);
    assert!(bps::max().apply_ceil(0) == 0);
}

// miso_share scale: SUPPLY 1e13 with 6 decimals.
#[test]
fun probe_share_supply_scale() {
    let supply = 10_000_000_000_000u64; // 1e13
    assert!(bps::new(1).apply(supply) == 1_000_000_000);
    assert!(bps::max().apply(supply) == supply);
    // half-split conservation at supply scale
    let (t, r) = bps::new(5_000).split(supply);
    assert!(t + r == supply);
}

// A naive `amount * bps / 10_000` in u64 overflows for amount > u64::MAX/10_000.
// The library must remain correct well past that boundary.
#[test]
fun probe_past_naive_overflow_boundary() {
    let naive_max = U64_MAX / 10_000; // 1_844_674_407_370_955_161
    let x = naive_max + 1;
    assert!(bps::new(5_000).apply(x) == x / 2);
    assert!(bps::new(9_999).apply(U64_MAX) <= U64_MAX);
}

// ceil/floor sandwich at extremes: floor <= ceil <= amount, gap <= 1.
#[test]
fun probe_ceil_floor_sandwich_extremes() {
    let b = bps::new(9_999);
    assert!(b.apply(U64_MAX) <= b.apply_ceil(U64_MAX));
    assert!(b.apply_ceil(U64_MAX) <= U64_MAX);
    assert!(b.apply_ceil(U64_MAX) - b.apply(U64_MAX) <= 1);
}

// split conservation sweep over awkward amounts and rates.
#[test]
fun probe_split_conservation_sweep() {
    let amounts = vector[1u64, 7, 9_999, 10_000, 10_001, U64_MAX];
    let rates = vector[1u16, 33, 3_333, 9_999, 10_000];
    amounts.do_ref!(|a| {
        rates.do_ref!(|r| {
            let b = bps::new(*r);
            let (t, rem) = b.split(*a);
            assert!(t + rem == *a);
            assert!(t == b.apply(*a));
        });
    });
}

// u256 ceil at the historical safe limit (pre-decomposition overflow
// boundary). u256 apply is now total, so this must not abort — and pins
// exactness at a large non-trivial amount.
#[test]
fun probe_ceil_u256_at_safe_limit() {
    let amount = std::u256::max_value!() / 10_000;
    assert!(bps::max().apply_ceil_u256(amount) == amount);
}

// u256 ceil/floor sandwich at a large non-round value.
#[test]
fun probe_ceil_u256_sandwich() {
    let b = bps::new(3_333);
    let x = 1_000_000_007u256;
    assert!(b.apply_u256(x) + 1 == b.apply_ceil_u256(x));
}
