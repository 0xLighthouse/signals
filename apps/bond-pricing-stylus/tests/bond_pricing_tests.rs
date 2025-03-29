use bond_pricing_stylus::{LinearBondPricing, utils::{mul_div_down, mul_div_up}};
use stylus_sdk::{
    alloy_primitives::U256,
    testing::*,
};

// Constants - matches PipsLib.OneHundred from the contract
const ONE_HUNDRED: U256 = U256::from_limbs([100_0000, 0, 0, 0]);

fn setup_contract() -> (TestVM, LinearBondPricing, U256, U256) {
    let vm = TestVM::default();
    let mut contract = LinearBondPricing::from(&vm);

    // Initialize with 10% bid discount and 10% ask premium
    let discount = U256::from(10_0000); // 10% in PIPS (10 * 10000)
    let premium = U256::from(10_0000);  // 10% in PIPS
    contract.constructor(discount, premium);

    (vm, contract, discount, premium)
}

fn get_test_parameters() -> (U256, U256, U256, Vec<u8>) {
    // Test parameters matching apps/bond-hook/test/ExampleLinearPricing.t.sol
    let token_amount = U256::from_str_radix("1000000000000000000", 10).unwrap(); // 1 ether
    let bond_created = U256::from(1739290000); // bondCreated timestamp
    let total_duration = U256::from(30 * 24 * 60 * 60); // 30 days in seconds
    let reference_id = Vec::new(); // Empty reference ID

    (token_amount, bond_created, total_duration, reference_id)
}

#[test]
fn test_constructor() {
    let (_, contract, discount, premium) = setup_contract();

    // Verify constructor values
    assert_eq!(contract.bid_discount(), discount);
    assert_eq!(contract.ask_premium(), premium);
}

#[test]
fn test_buy_price_after_maturity() {
    let (_, contract, discount, _) = setup_contract();
    let (token_amount, bond_created, total_duration, reference_id) = get_test_parameters();
    
    // Time after maturity
    let after_maturity = bond_created + U256::from(40 * 24 * 60 * 60); // +40 days
    
    let buy_after_mature = contract.get_buy_price(
        token_amount,
        bond_created,
        total_duration,
        after_maturity,
        reference_id
    );

    // We expect full amount minus discount
    let expected_buy_after_mature = token_amount - mul_div_down(token_amount, discount, ONE_HUNDRED);
    assert_eq!(buy_after_mature, expected_buy_after_mature);
}

#[test]
fn test_buy_price_before_maturity() {
    let (_, contract, discount, _) = setup_contract();
    let (token_amount, bond_created, total_duration, reference_id) = get_test_parameters();
    
    // Time at 50% of duration
    let at_fifty_percent = bond_created + U256::from(15 * 24 * 60 * 60); // +15 days
    
    let buy_at_fifty = contract.get_buy_price(
        token_amount,
        bond_created,
        total_duration,
        at_fifty_percent,
        reference_id
    );

    // At 50% of the way to maturity, the bond is worth 50% of principal
    let value_at_time = token_amount / U256::from(2);
    let discount_at_time = mul_div_down(value_at_time, discount, ONE_HUNDRED);
    let expected_buy_at_fifty = value_at_time - discount_at_time;
    assert_eq!(buy_at_fifty, expected_buy_at_fifty);
}

#[test]
fn test_sell_price_after_maturity() {
    let (_, contract, _, premium) = setup_contract();
    let (token_amount, bond_created, total_duration, reference_id) = get_test_parameters();
    
    // Time after maturity
    let after_maturity = bond_created + U256::from(40 * 24 * 60 * 60); // +40 days
    
    let sell_after_mature = contract.get_sell_price(
        token_amount,
        bond_created,
        total_duration,
        after_maturity,
        reference_id
    );

    // We expect full amount plus premium
    let expected_sell_after_mature = token_amount + mul_div_up(token_amount, premium, ONE_HUNDRED);
    assert_eq!(sell_after_mature, expected_sell_after_mature);
}

#[test]
fn test_sell_price_before_maturity() {
    let (_, contract, _, premium) = setup_contract();
    let (token_amount, bond_created, total_duration, reference_id) = get_test_parameters();
    
    // Time at 50% of duration
    let at_fifty_percent = bond_created + U256::from(15 * 24 * 60 * 60); // +15 days
    
    let sell_at_fifty = contract.get_sell_price(
        token_amount,
        bond_created,
        total_duration,
        at_fifty_percent,
        reference_id
    );

    // At 50% of the way to maturity, the bond is worth 50% of principal
    let value_at_time = token_amount / U256::from(2);
    let premium_at_time = mul_div_up(value_at_time, premium, ONE_HUNDRED);
    let expected_sell_at_fifty = value_at_time + premium_at_time;
    assert_eq!(sell_at_fifty, expected_sell_at_fifty);
}