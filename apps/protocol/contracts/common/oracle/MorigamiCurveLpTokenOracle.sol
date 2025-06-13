pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiCurveLpTokenOracle.sol)

import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {ICurvePool} from "contracts/interfaces/external/curve/ICurvePool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title MorigamiCurveLpTokenOracle
 * @notice The oracle price is calculated based on the price of the quote token in the CurvePool
 * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
 */
contract MorigamiCurveLpTokenOracle is MorigamiOracleBase {

    error UnknownAsset(address asset);

    ICurvePool public immutable curvePool;
    mapping(address => uint256) public assetIndices;

    constructor(
        BaseOracleParams memory baseParams,
        address _curvePool,
        address[] memory higherIndexAssets_
    ) MorigamiOracleBase(baseParams) {
        curvePool = ICurvePool(_curvePool);
        assetIndices[baseParams.quoteAssetAddress] = type(uint256).max;
        for (uint256 i = 1; i <= higherIndexAssets_.length;) {
            // index 0 is preserved for quoteAsset
            // write asset indices starting from 1
            assetIndices[higherIndexAssets_[i]] = i;
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Return the current conversion rate a.k.a price for 1 lpToken in quoteAsset
     * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
     */
    function latestPrice(
        PriceType,
        MorigamiMath.Rounding
    ) public view override returns (uint256 price) {
        // should take into account decimals difference between baseAsset and quoteAsset
        price = curvePool.get_virtual_price();
    }

    function convertAmount(
        address fromAsset,
        uint256 fromAssetAmount,
        PriceType,
        MorigamiMath.Rounding
    ) public view override(MorigamiOracleBase) returns (uint256) {
        if (assetIndices[fromAsset] == 0) {
            revert UnknownAsset(fromAsset);
        }
        uint8 baseDecimals = IERC20Metadata(baseAsset).decimals();
        // if converting from base asset return lp price in quote
        if (fromAsset == baseAsset) return curvePool.get_virtual_price() * fromAssetAmount / 10 ** baseDecimals;

        // get lp price in quote
        uint256 lpPrice = curvePool.get_virtual_price();
        // if from asset is quote asset return base asset
        if (assetIndices[fromAsset] == type(uint256).max) {
            return fromAssetAmount * 10 ** baseDecimals / lpPrice;
        }
        uint8 quoteDecimals = IERC20Metadata(quoteAsset).decimals();
        // calc price of asset at index
        uint256 fromAssetPriceInquote = curvePool.price_oracle(assetIndices[fromAsset]);
        // calc amount of from asset in quoute asset
        uint256 fromAmountInQuoute = fromAssetAmount * fromAssetPriceInquote / 10 ** quoteDecimals;
        // return lp amount
        return fromAmountInQuoute * 10 ** baseDecimals / lpPrice;
    }

}
