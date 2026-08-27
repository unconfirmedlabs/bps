module bps_specs::bps_specs;

use bps::bps::{Self, BPS};

#[spec_only]
use prover::prover::{asserts, ensures, requires};

const DENOMINATOR: u16 = 10_000;

#[spec(prove, target = bps::new)]
public fun new_spec(v: u16): BPS {
    asserts(v <= DENOMINATOR);
    let result = bps::new(v);
    ensures(bps::value(result) == v);
    result
}

#[spec(prove, target = bps::from_percent)]
public fun from_percent_spec(pct: u8): BPS {
    asserts(pct <= 100);
    let result = bps::from_percent(pct);
    ensures(bps::value(result) == (pct as u16) * 100);
    ensures(bps::value(result) <= DENOMINATOR);
    result
}

#[spec(prove, target = bps::zero)]
public fun zero_spec(): BPS {
    let result = bps::zero();
    ensures(bps::value(result) == 0);
    result
}

#[spec(prove, target = bps::max)]
public fun max_spec(): BPS {
    let result = bps::max();
    ensures(bps::value(result) == DENOMINATOR);
    result
}

#[spec(prove, target = bps::value)]
public fun value_spec(b: BPS): u16 {
    let result = bps::value(b);
    ensures(result == bps::spec_value(b));
    result
}

#[spec(prove, target = bps::is_zero)]
public fun is_zero_spec(b: BPS): bool {
    let v = bps::spec_value(b);
    let result = bps::is_zero(b);
    ensures(result == (v == 0));
    result
}

#[spec(prove, target = bps::is_max)]
public fun is_max_spec(b: BPS): bool {
    let v = bps::spec_value(b);
    let result = bps::is_max(b);
    ensures(result == (v == DENOMINATOR));
    result
}

#[spec(prove, target = bps::add)]
public fun add_spec(a: BPS, b: BPS): BPS {
    let av = bps::spec_value(a);
    let bv = bps::spec_value(b);
    requires(av <= DENOMINATOR);
    requires(bv <= DENOMINATOR);
    asserts(av + bv <= DENOMINATOR);
    let result = bps::add(a, b);
    ensures(bps::value(result) == av + bv);
    ensures(bps::value(result) <= DENOMINATOR);
    result
}

#[spec(prove, target = bps::sub)]
public fun sub_spec(a: BPS, b: BPS): BPS {
    let av = bps::spec_value(a);
    let bv = bps::spec_value(b);
    requires(av <= DENOMINATOR);
    requires(bv <= DENOMINATOR);
    asserts(av >= bv);
    let result = bps::sub(a, b);
    ensures(bps::value(result) == av - bv);
    ensures(bps::value(result) <= DENOMINATOR);
    result
}

#[spec(prove, target = bps::complement)]
public fun complement_spec(b: BPS): BPS {
    let v = bps::spec_value(b);
    requires(v <= DENOMINATOR);
    let result = bps::complement(b);
    ensures(bps::value(result) == DENOMINATOR - v);
    ensures(bps::value(result) <= DENOMINATOR);
    result
}

#[spec(prove, target = bps::apply)]
public fun apply_spec(b: BPS, amount: u64): u64 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let product = amount.to_int().mul(rate.to_int());
    let expected = product.div(10_000u64.to_int());
    let result = bps::apply(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil)]
public fun apply_ceil_spec(b: BPS, amount: u64): u64 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let product = amount.to_int().mul(rate.to_int());
    let expected = product.add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split)]
public fun split_spec(b: BPS, amount: u64): (u64, u64) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove, target = bps::apply_u8)]
public fun apply_u8_spec(b: BPS, amount: u8): u8 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let result = bps::apply_u8(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil_u8)]
public fun apply_ceil_u8_spec(b: BPS, amount: u8): u8 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil_u8(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split_u8)]
public fun split_u8_spec(b: BPS, amount: u8): (u8, u8) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split_u8(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove, target = bps::apply_u16)]
public fun apply_u16_spec(b: BPS, amount: u16): u16 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let result = bps::apply_u16(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil_u16)]
public fun apply_ceil_u16_spec(b: BPS, amount: u16): u16 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil_u16(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split_u16)]
public fun split_u16_spec(b: BPS, amount: u16): (u16, u16) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split_u16(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove, target = bps::apply_u32)]
public fun apply_u32_spec(b: BPS, amount: u32): u32 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let result = bps::apply_u32(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil_u32)]
public fun apply_ceil_u32_spec(b: BPS, amount: u32): u32 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil_u32(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split_u32)]
public fun split_u32_spec(b: BPS, amount: u32): (u32, u32) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split_u32(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove, target = bps::apply_u128)]
public fun apply_u128_spec(b: BPS, amount: u128): u128 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let result = bps::apply_u128(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil_u128)]
public fun apply_ceil_u128_spec(b: BPS, amount: u128): u128 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil_u128(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split_u128)]
public fun split_u128_spec(b: BPS, amount: u128): (u128, u128) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split_u128(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove, target = bps::apply_u256)]
public fun apply_u256_spec(b: BPS, amount: u256): u256 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let result = bps::apply_u256(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::apply_ceil_u256)]
public fun apply_ceil_u256_spec(b: BPS, amount: u256): u256 {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).add(9_999u64.to_int()).div(10_000u64.to_int());
    let result = bps::apply_ceil_u256(b, amount);
    ensures(result.to_int() == expected);
    ensures(result <= amount);
    result
}

#[spec(prove, target = bps::split_u256)]
public fun split_u256_spec(b: BPS, amount: u256): (u256, u256) {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let expected = amount.to_int().mul(rate.to_int()).div(10_000u64.to_int());
    let (taken, remainder) = bps::split_u256(b, amount);
    ensures(taken.to_int() == expected);
    ensures(taken.to_int().add(remainder.to_int()) == amount.to_int());
    (taken, remainder)
}

#[spec(prove)]
public fun denominator_scenario(): u16 {
    let result = bps::denominator!();
    ensures(result == DENOMINATOR);
    result
}

#[spec(prove)]
public fun complement_involution_scenario(b: BPS): BPS {
    let rate = bps::spec_value(b);
    requires(rate <= DENOMINATOR);
    let first = bps::complement(b);
    let result = bps::complement(first);
    ensures(bps::value(first) + rate == DENOMINATOR);
    ensures(bps::value(result) == rate);
    result
}
