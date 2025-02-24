import {BondHook} from "../../src/BondHook.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

library BondHookUtils {
  function addLiquidity(BondHook bondhook, PoolKey memory key, int128 liquidity) public {
   
    ERC20 currency0 = ERC20(Currency.unwrap(key.currency0));
    ERC20 currency1 = ERC20(Currency.unwrap(key.currency1));
    currency0.approve(address(bondhook), 100 ether);
    currency1.approve(address(bondhook), 100 ether);

    // Add liquidity to pool
    bondhook.modifyLiquidity(
        key,
        liquidity
    );
  }
}