//!
//! Stylus Bond Pricing
//!
//! Linear Bond Pricing model implemented in Stylus (Rust)
//!

// Allow `cargo stylus export-abi` to generate a main function.
#![cfg_attr(not(any(test, feature = "export-abi")), no_main)]
extern crate alloc;

/// Import items from the SDK
use stylus_sdk::{
    alloy_primitives::U256,
    prelude::*,
};

// Import utility functions
pub mod utils;
use utils::{mul_div_down, mul_div_up};

// Define storage layout for LinearBondPricing contract
sol_storage! {
    #[entrypoint]
    pub struct LinearBondPricing {
        uint256 bid_discount;
        uint256 ask_premium;
    }
}

// Constants - matches PipsLib.OneHundred from the test
pub const ONE_HUNDRED: U256 = U256::from_limbs([100_0000, 0, 0, 0]);

/// Implementation of the IBondPricing interface
#[public]
impl LinearBondPricing {
    /// Constructor to set the bid discount and ask premium
    pub fn constructor(&mut self, bid_discount: U256, ask_premium: U256) {
        self.bid_discount.set(bid_discount);
        self.ask_premium.set(ask_premium);
    }

    /// Get the current bid discount
    pub fn bid_discount(&self) -> U256 {
        self.bid_discount.get()
    }

    /// Get the current ask premium
    pub fn ask_premium(&self) -> U256 {
        self.ask_premium.get()
    }

    /// Returns the price at which the pool would buy a bond
    pub fn get_buy_price(
        &self,
        principal: U256,
        start_time: U256,
        duration: U256,
        current_time: U256,
        _reference_id: Vec<u8>,
    ) -> U256 {
        let current_value = self.calculate_current_bond_value(principal, start_time, duration, current_time);
        let discount = mul_div_down(current_value, self.bid_discount.get(), ONE_HUNDRED);

        if current_value > discount {
            current_value - discount
        } else {
            U256::ZERO
        }
    }

    /// Returns the price at which the pool would sell a bond
    pub fn get_sell_price(
        &self,
        principal: U256,
        start_time: U256,
        duration: U256,
        current_time: U256,
        _reference_id: Vec<u8>,
    ) -> U256 {
        let current_value = self.calculate_current_bond_value(principal, start_time, duration, current_time);
        let premium = mul_div_up(current_value, self.ask_premium.get(), ONE_HUNDRED);

        current_value + premium
    }

    /// Calculates the current value of a bond based on time
    /// Matches the _calculateCurrentBondValue in the Solidity contract
    fn calculate_current_bond_value(
        &self,
        principal: U256,
        start_time: U256,
        duration: U256,
        current_time: U256,
    ) -> U256 {
        let end_time = start_time + duration;

        // If the bond is already matured, return the full principal
        if current_time >= end_time {
            return principal;
        }

        // Calculate remaining duration
        let remaining_duration = end_time - current_time;

        // Calculate value based on linear model
        // This is equivalent to:
        // principal - principal.mulDivDown(remainingDuration, duration)
        let discount = mul_div_down(principal, remaining_duration, duration);

        if principal > discount {
            principal - discount
        } else {
            U256::ZERO
        }
    }
}