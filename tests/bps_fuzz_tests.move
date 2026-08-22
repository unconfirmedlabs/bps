#[test_only]
module bps::bps_fuzz_tests;

use bps::bps;

const U64_MAX: u64 = 18_446_744_073_709_551_615;
const U128_MAX: u128 = 340_282_366_920_938_463_463_374_607_431_768_211_455;

// === Deterministic PRNG ===
//
// xorshift64: shift/xor only, so no overflow aborts and no environment
// dependence. Fixed seed => reproducible draws on every run.

public struct Rng(u64) has drop;

fun rng(seed: u64): Rng {
    // xorshift state must be nonzero.
    Rng(if (seed == 0) 0x9E3779B97F4A7C15 else seed)
}

fun next(r: &mut Rng): u64 {
    let mut x = r.0;
    x = x ^ (x << 13);
    x = x ^ (x >> 7);
    x = x ^ (x << 17);
    r.0 = x;
    x
}

/// Uniform draw in `[0, 10_000]`.
fun next_bps(r: &mut Rng): u16 {
    (next(r) % 10_001) as u16
}

fun next_u128(r: &mut Rng): u128 {
    ((next(r) as u128) << 64) | (next(r) as u128)
}

fun next_u256(r: &mut Rng): u256 {
    ((next_u128(r) as u256) << 128) | (next_u128(r) as u256)
}

// === Shared property assertions (u64) ===

fun check_u64(v: u16, x: u64) {
    let b = bps::new(v);
    let floor = b.apply(x);
    let ceil = b.apply_ceil(x);
    let (taken, remainder) = b.split(x);
    // conservation: split is exact and agrees with apply
    assert!(taken == floor);
    assert!(taken + remainder == x);
    // bound: floor and ceil never exceed the amount
    assert!(floor <= x);
    assert!(ceil <= x);
    // floor/ceil sandwich (subtraction is safe: floor <= ceil)
    assert!(ceil - floor <= 1);
    // endpoints
    if (v == 0) assert!(floor == 0);
    if (v == 10_000) {
        assert!(floor == x);
        assert!(ceil == x);
    };
}

// === 1. Exhaustive bps sweep (u64), one test per amount ===

fun sweep_all_bps(x: u64) {
    let mut v = 0u16;
    while (v <= 10_000) {
        check_u64(v, x);
        v = v + 1;
    };
}

#[test]
fun sweep_amount_0() { sweep_all_bps(0); }

#[test]
fun sweep_amount_1() { sweep_all_bps(1); }

#[test]
fun sweep_amount_2() { sweep_all_bps(2); }

#[test]
fun sweep_amount_9999() { sweep_all_bps(9_999); }

#[test]
fun sweep_amount_10000() { sweep_all_bps(10_000); }

#[test]
fun sweep_amount_10001() { sweep_all_bps(10_001); }

#[test]
fun sweep_amount_65535() { sweep_all_bps(65_535); }

#[test]
fun sweep_amount_share_supply() { sweep_all_bps(1_000_000_000_000); }

#[test]
fun sweep_amount_u64_max() { sweep_all_bps(U64_MAX); }

// === 2. PRNG fuzz: u64 and u128 ===

const FUZZ_ITERS: u64 = 6_000;

#[test]
fun fuzz_u64() {
    let mut r = rng(0xB05_5EED);
    let mut i = 0;
    while (i < FUZZ_ITERS) {
        // Force boundary amounts on a regular cadence.
        let x = if (i % 64 == 32) { U64_MAX } else { next(&mut r) };
        // Force boundary bps (0, 1, 10_000) on a regular cadence.
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        check_u64(v, x);
        // monotonicity: b1 <= b2 => apply(b1, x) <= apply(b2, x)
        let a = next_bps(&mut r);
        let b = next_bps(&mut r);
        let (lo, hi) = if (a <= b) (a, b) else (b, a);
        assert!(bps::new(lo).apply(x) <= bps::new(hi).apply(x));
        i = i + 1;
    };
}

#[test]
fun fuzz_u128() {
    let mut r = rng(0xB05_5EED_128);
    let mut i = 0;
    while (i < FUZZ_ITERS) {
        let x = if (i % 64 == 32) { U128_MAX } else { next_u128(&mut r) };
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        let b = bps::new(v);
        let floor = b.apply_u128(x);
        let ceil = b.apply_ceil_u128(x);
        let (taken, remainder) = b.split_u128(x);
        assert!(taken == floor);
        assert!(taken + remainder == x);
        assert!(floor <= x);
        assert!(ceil <= x);
        assert!(ceil - floor <= 1);
        if (v == 0) assert!(floor == 0);
        if (v == 10_000) {
            assert!(floor == x);
            assert!(ceil == x);
        };
        let a = next_bps(&mut r);
        let b2 = next_bps(&mut r);
        let (lo, hi) = if (a <= b2) (a, b2) else (b2, a);
        assert!(bps::new(lo).apply_u128(x) <= bps::new(hi).apply_u128(x));
        i = i + 1;
    };
}

// === 3. u256 fuzz (full domain — apply_u256 is total) ===

#[test]
fun fuzz_u256() {
    // u256 apply uses quotient/remainder decomposition: no abort at any
    // amount, including u256::MAX. Draw from the FULL domain and force
    // u256::MAX on a cadence.
    let max = std::u256::max_value!();
    let mut r = rng(0xB05_5EED_256);
    let mut i = 0u64;
    while (i < 1_000) {
        let x = if (i % 64 == 32) { max } else { next_u256(&mut r) };
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        let b = bps::new(v);
        let floor = b.apply_u256(x);
        let ceil = b.apply_ceil_u256(x);
        let (taken, remainder) = b.split_u256(x);
        assert!(taken == floor);
        assert!(taken + remainder == x);
        assert!(floor <= x);
        assert!(ceil <= x);
        assert!(ceil - floor <= 1);
        if (v == 0) assert!(floor == 0);
        if (v == 10_000) {
            assert!(floor == x);
            assert!(ceil == x);
        };
        i = i + 1;
    };
}

// === 4. Narrow widths: u8 / u16 / u32 ===

#[test]
fun fuzz_u8() {
    let mut r = rng(0xB05_5EED_8);
    let mut i = 0u64;
    while (i < 1_000) {
        let x = if (i % 64 == 32) { 255u8 } else { (next(&mut r) % 256) as u8 };
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        let b = bps::new(v);
        let floor = b.apply_u8(x);
        let ceil = b.apply_ceil_u8(x);
        let (taken, remainder) = b.split_u8(x);
        assert!(taken == floor);
        assert!(taken + remainder == x);
        assert!(floor <= x);
        assert!(ceil <= x);
        assert!(ceil - floor <= 1);
        i = i + 1;
    };
}

#[test]
fun fuzz_u16() {
    let mut r = rng(0xB05_5EED_16);
    let mut i = 0u64;
    while (i < 1_000) {
        let x = if (i % 64 == 32) { 65_535u16 } else { (next(&mut r) % 65_536) as u16 };
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        let b = bps::new(v);
        let floor = b.apply_u16(x);
        let ceil = b.apply_ceil_u16(x);
        let (taken, remainder) = b.split_u16(x);
        assert!(taken == floor);
        assert!(taken + remainder == x);
        assert!(floor <= x);
        assert!(ceil <= x);
        assert!(ceil - floor <= 1);
        i = i + 1;
    };
}

#[test]
fun fuzz_u32() {
    let mut r = rng(0xB05_5EED_32);
    let mut i = 0u64;
    while (i < 1_000) {
        let x = if (i % 64 == 32) { 4_294_967_295u32 } else { (next(&mut r) % 4_294_967_296) as u32 };
        let v = if (i % 64 == 0) {
            ((i / 64) % 3) as u16 * if ((i / 64) % 3 == 2) { 5_000 } else { 1 }
        } else {
            next_bps(&mut r)
        };
        let b = bps::new(v);
        let floor = b.apply_u32(x);
        let ceil = b.apply_ceil_u32(x);
        let (taken, remainder) = b.split_u32(x);
        assert!(taken == floor);
        assert!(taken + remainder == x);
        assert!(floor <= x);
        assert!(ceil <= x);
        assert!(ceil - floor <= 1);
        i = i + 1;
    };
}

// === 5. Abort-code literal pin ===

// Off-chain integrators match on raw abort codes; a silent renumbering of
// `EOverflow` / `EUnderflow` would break them without a compile error.
// The constants are module-internal, so the literal values are pinned via
// `expected_failure` abort codes instead of direct references.
#[test, expected_failure(abort_code = 0)]
fun abort_code_overflow_is_zero() {
    // EOverflow == 0
    bps::new(10_001);
}

#[test, expected_failure(abort_code = 1)]
fun abort_code_underflow_is_one() {
    // EUnderflow == 1
    bps::new(2_000).sub(bps::new(3_000));
}

// === 6. Regression anchors ===

#[test]
fun apply_ceil_at_zero_amount_is_zero() {
    let rates = vector[0u16, 1, 33, 5_000, 9_999, 10_000];
    rates.do_ref!(|v| {
        let b = bps::new(*v);
        assert!(b.apply_ceil(0) == 0);
        assert!(b.apply_ceil_u8(0) == 0);
        assert!(b.apply_ceil_u16(0) == 0);
        assert!(b.apply_ceil_u32(0) == 0);
        assert!(b.apply_ceil_u128(0) == 0);
        assert!(b.apply_ceil_u256(0) == 0);
    });
}

// Double-floor drift: apply(b, x) + apply(complement(b), x) may be x or x-1,
// never anything else. Swept exhaustively over all bps for a few amounts.
#[test]
fun complement_drift_is_at_most_one() {
    let amounts = vector[1u64, 7, 100, 9_999, 10_001];
    amounts.do_ref!(|x| {
        let mut v = 0u16;
        while (v <= 10_000) {
            let b = bps::new(v);
            let sum = b.apply(*x) + b.complement().apply(*x);
            assert!(sum <= *x);
            assert!(*x - sum <= 1);
            v = v + 1;
        };
    });
}
