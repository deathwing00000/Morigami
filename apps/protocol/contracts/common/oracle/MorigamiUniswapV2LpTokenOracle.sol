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
        (uint token0, uint token1, ) = IUniswapV2Pair(baseAsset).getReserves();

        // on remove liquidity, we get half of the withdrawn amount in
        // token0 and half of in token1, the prices of amount0 and amount1 should be equal
        // according to lp pool ratio. Since their price are the same, then total price of
        // lp token is 2x of the price of token0 or token1 in current state.
        price = quoteAsset == IUniswapV2Pair(baseAsset).token0()
            ? token0.mulDiv(balance, totalSupply, roundingMode) * 2
            : token1.mulDiv(balance, totalSupply, roundingMode) * 2;

        price =
            (price * 10 ** decimals) /
            10 ** (IERC20Metadata(quoteAsset).decimals());
    }
}
