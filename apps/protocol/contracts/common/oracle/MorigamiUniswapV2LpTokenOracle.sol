pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiUniswapV2LpTokenOracle.sol)

import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV2Pair} from "contracts/interfaces/external/uniswap/IUniswapV2Pair.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";

/**
 * @title MorigamiUniswapV2LpTokenOracle
 * @notice Oracle price is calculated based on the price of the quote token in the UniswapV2Pair
 * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
 */
contract MorigamiUniswapV2LpTokenOracle is MorigamiOracleBase {
    using MorigamiMath for uint256;

    error QuoteAssetIsNotInPair(address);

    IAggregatorV3Interface immutable public oracleToken0;
    IAggregatorV3Interface immutable public oracleToken1;

    constructor(
        address _initialOwner,
        BaseOracleParams memory baseParams,
        IAggregatorV3Interface _oracleToken0, 
        IAggregatorV3Interface _oracleToken1
    ) MorigamiOracleBase(baseParams) {
        address baseAsset = baseParams.baseAssetAddress;
        if (baseParams.quoteAssetAddress != IUniswapV2Pair(baseAsset).token0() && 
            baseParams.quoteAssetAddress != IUniswapV2Pair(baseAsset).token1()) {
                revert QuoteAssetIsNotInPair(baseParams.quoteAssetAddress);
        }
        oracleToken0 = _oracleToken0;
        oracleToken1 = _oracleToken1;
    }

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
        
        (uint reserve0, uint reserve1, ) = IUniswapV2Pair(baseAsset).getReserves();

        // Get token addresses from the pair
        address token0 = IUniswapV2Pair(baseAsset).token0();
        address token1 = IUniswapV2Pair(baseAsset).token1();

        uint d0 = IERC20Metadata(token0).decimals();
        uint d1 = IERC20Metadata(token1).decimals();
        uint256 price0 = uint256(oracleToken0.latestAnswer());
        uint256 price1 = uint256(oracleToken1.latestAnswer());

        uint totalValues = 2 * MorigamiMath.sqrt(price0 * reserve0 / 10 ** d0 *  price1 * reserve1 / 10 ** d1);
        price = totalValues.mulDiv(balance, totalSupply, roundingMode);
        if (quoteAsset == token0) {
            price = price * 10 ** oracleToken0.decimals() / price0;
        } else {
            price = price * 10 ** oracleToken1.decimals() / price1;
        }  
    }
}
