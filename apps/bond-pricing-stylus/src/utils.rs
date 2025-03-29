//!
//! Utility functions for bond pricing calculations
//!

use stylus_sdk::alloy_primitives::{U256, U512};

/// Safely convert U512 to U256 if possible
pub fn u512_to_u256(value: U512) -> U256 {
    // Check if the high 256 bits are all zeros
    let high_bits_zero = value >> 256 == U512::ZERO;

    if high_bits_zero {
        // Only keep the lower 256 bits
        let mask = U512::from(U256::MAX);
        let lower_bits = value & mask;

        // We know the high bits are zero, so we can safely convert
        // by taking just the first 4 limbs
        let limbs = lower_bits.as_limbs();
        U256::from_limbs([limbs[0], limbs[1], limbs[2], limbs[3]])
    } else {
        U256::MAX // Overflow, return max value
    }
}

/// Multiply and divide, rounding down
pub fn mul_div_down(a: U256, b: U256, denominator: U256) -> U256 {
    // Convert to U512 to prevent overflow
    let a_512 = U512::from(a);
    let b_512 = U512::from(b);
    let denominator_512 = U512::from(denominator);

    // Perform the calculation
    let product = a_512 * b_512;
    let quotient = product / denominator_512;

    // Convert back to U256
    u512_to_u256(quotient)
}

/// Multiply and divide, rounding up
pub fn mul_div_up(a: U256, b: U256, denominator: U256) -> U256 {
    // Convert to U512 to prevent overflow
    let a_512 = U512::from(a);
    let b_512 = U512::from(b);
    let denominator_512 = U512::from(denominator);

    // Perform the calculation
    let product = a_512 * b_512;
    let quotient = product / denominator_512;

    // Add 1 if there's a remainder
    let remainder = product % denominator_512;
    let adjusted = if remainder > U512::ZERO {
        quotient + U512::from(1u64)
    } else {
        quotient
    };

    // Convert back to U256
    u512_to_u256(adjusted)
}