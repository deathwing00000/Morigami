pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiUniswapV2LpTokenOracle.sol)

import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV2Pair} from "contracts/interfaces/external/uniswap/IUniswapV2Pair.sol";

/**
 * @title MorigamiUniswapV2LpTokenOracle
 * @notice Oracle price is calculated based on the price of the quote token in the UniswapV2Pair
 * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
 */
contract MorigamiUniswapV2LpTokenOracle is MorigamiOracleBase {
    using MorigamiMath for uint256;
    constructor(
        address _initialOwner,
        BaseOracleParams memory baseParams
    ) MorigamiOracleBase(baseParams) {}

    /**
     * @notice Return the current conversion rate a.k.a price for 1 lpToken in quoteAsset
     * @param roundingMode Round the price at each intermediate step such that the final price rounds in the specified direction.
     * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
     */
    function latestPrice(
        PriceType,
        MorigamiMath.Rounding roundingMode
    ) public view override returns (uint256 price) {
        uint totalSupply = IERC20(baseAsset).totalSupply();
        uint balance = 1 * 10 ** IERC20Metadata(baseAsset).decimals();
        
        // Get current reserves and calculate k
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(baseAsset).getReserves();
        uint k = reserve0 * reserve1;
        
        // Calculate fair reserves based on the current price ratio
        uint priceRatio = reserve0.mulDiv(1e18, reserve1, roundingMode);
        uint fairReserve0 = MorigamiMath.sqrt(k.mulDiv(priceRatio, 1e18, roundingMode));
        uint fairReserve1 = MorigamiMath.sqrt(k.mulDiv(1e18, priceRatio, roundingMode));
        
        // Calculate our share of the fair reserves
        uint amount0 = fairReserve0.mulDiv(balance, totalSupply, roundingMode);
        uint amount1 = fairReserve1.mulDiv(balance, totalSupply, roundingMode);
        
        // Convert both amounts to quoteAsset using the fair reserves ratio
        if (quoteAsset == IUniswapV2Pair(baseAsset).token0()) {
            price = amount0 + amount1.mulDiv(fairReserve0, fairReserve1, roundingMode);
        } else {
            price = amount1 + amount0.mulDiv(fairReserve1, fairReserve0, roundingMode);
        }
    }
}
