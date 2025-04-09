pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiScaledOracle.sol)

import { IMorigamiOracle } from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import { MorigamiOracleBase } from "contracts/common/oracle/MorigamiOracleBase.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

contract MorigamiScaledOracle is MorigamiOracleBase {
    using MorigamiMath for uint256;

    /**
     * @notice The reference price oracle. This scaled oracle will have the same
     * `baseAsset` and `quoteAsset`, but the price will be scaled by the latest
     * price from `scalarOracle`
     */
    IMorigamiOracle public immutable referenceOracle;

    /**
     * @notice The oracle to use to retrieve the scalar, applied to the `referenceOracle` price.
     * @dev The baseAsset and quoteAsset addresses within `scalarOracle` must be address(0)
     * denoting it is a scalar.
     */
    IMorigamiOracle public immutable scalarOracle;

    /**
     * @notice
     *  - True to multiply: referenceOracle.latestPrice() * scalarOracle.latestPrice()
     *  - False to divide:  referenceOracle.latestPrice() / scalarOracle.latestPrice()
     */
    bool public immutable multiply;

    constructor (
        BaseOracleParams memory baseParams,
        address _referenceOracle,
        address _scalarOracle,
        bool _multiply
    ) MorigamiOracleBase(baseParams)
    {
        referenceOracle = IMorigamiOracle(_referenceOracle);
        scalarOracle = IMorigamiOracle(_scalarOracle);

        if (baseAsset != referenceOracle.baseAsset()) revert CommonEventsAndErrors.InvalidAddress(baseAsset);
        if (quoteAsset != referenceOracle.quoteAsset()) revert CommonEventsAndErrors.InvalidAddress(quoteAsset);
        if (assetScalingFactor != referenceOracle.assetScalingFactor()) revert CommonEventsAndErrors.InvalidParam();

        // The baseAsset and quoteAsset must be address(0), since it needs to represent a unitless scalar
        if (scalarOracle.baseAsset() != address(0) || scalarOracle.quoteAsset() != address(0)) revert CommonEventsAndErrors.InvalidParam();
        if (scalarOracle.assetScalingFactor() != precision) revert CommonEventsAndErrors.InvalidParam();

        multiply = _multiply;
    }

    /**
     * @notice Return the latest oracle price, to `decimals` precision
     * @dev This may still revert - eg if deemed stale, div by 0, negative price
     * @param priceType What kind of price - Spot or Historic
     * @param roundingMode Round the price at each intermediate step such that the final price rounds in the specified direction.
     */
    function latestPrice(
        PriceType priceType, 
        MorigamiMath.Rounding roundingMode
    ) public override view returns (uint256) {
        // referenceOracle (the numerator) price follows the requested roundingMode
        // So if roundDown, then we want the numerator to be lower (round down)
        uint256 _referencePrice = referenceOracle.latestPrice(
            priceType, 
            roundingMode
        );

        if (multiply) {
            // Also the numerator - so follow the requested roundingMode
            uint256 _scalarPrice = scalarOracle.latestPrice(
                priceType, 
                roundingMode
            );

            return _referencePrice.mulDiv(_scalarPrice, precision, roundingMode);
        } else {
            // scalarOracle (the denominator) price follows the opposite roundingMode
            // So if roundDown, then we want the denominator to be higher (round up)
            uint256 _scalarPrice = scalarOracle.latestPrice(
                priceType, 
                roundingMode == MorigamiMath.Rounding.ROUND_DOWN ? MorigamiMath.Rounding.ROUND_UP : MorigamiMath.Rounding.ROUND_DOWN
            );
            if (_scalarPrice == 0) revert InvalidPrice(address(scalarOracle), int256(_scalarPrice));

            // Final price follows the requested roundingMode
            return _referencePrice.mulDiv(precision, _scalarPrice, roundingMode);
        }
    }
}
