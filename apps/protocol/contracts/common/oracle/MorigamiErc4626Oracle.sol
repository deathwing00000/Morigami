pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiErc4626Oracle.sol)

import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import { IMorigamiOracle } from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import { MorigamiOracleBase } from "contracts/common/oracle/MorigamiOracleBase.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

/**
 * @title MorigamiErc4626Oracle
 * @notice The price is represented by an ERC-4626 vault, optionally multiplied
 * by another Morigami oracle price
 */
contract MorigamiErc4626Oracle is MorigamiOracleBase {
    using MorigamiMath for uint256;

    /**
     * @notice The Morigami oracle for the quoteToken
     */
    IMorigamiOracle public immutable quoteAssetOracle;

    constructor (
        BaseOracleParams memory baseParams,
        address _quoteAssetOracle
    ) 
        MorigamiOracleBase(baseParams)
    {
        quoteAssetOracle = IMorigamiOracle(_quoteAssetOracle);
    }

    /**
     * @notice Return the latest oracle price, to `decimals` precision
     * @param priceType What kind of price - Spot or Historic
     * @param roundingMode Round the price at each intermediate step such that the final price rounds in the specified direction.
     */
    function latestPrice(
        PriceType priceType, 
        MorigamiMath.Rounding roundingMode
    ) public override view returns (uint256 price) {
        // How many assets for 1e18 shares
        price = IERC4626(baseAsset).convertToAssets(precision);

        // Convert to the quote asset if required
        if (address(quoteAssetOracle) != address(0)) {
            price = price.mulDiv(
                quoteAssetOracle.latestPrice(priceType, roundingMode),
                precision,
                roundingMode
            );
        }
    }
}
