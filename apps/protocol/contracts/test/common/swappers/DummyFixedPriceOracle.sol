pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { MorigamiOracleBase } from "contracts/common/oracle/MorigamiOracleBase.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

/**
 * @title DummyFixedPriceOracle
 * @notice A fixed price oracle only for both SPOT_PRICE and HISTORIC_PRICE
 */
contract DummyFixedPriceOracle is MorigamiOracleBase {
    /**
     * @notice The fixed price which this oracle returns.
     */
    uint256 private fixedPrice;

    constructor (
        BaseOracleParams memory baseParams,
        uint256 _fixedPrice
    )
        MorigamiOracleBase(baseParams)
    {
        fixedPrice = _fixedPrice;
    }

    function setFixedPrice(uint256 price) external {
        fixedPrice = price;
    }

    /**
     * @notice Return the fixed oracle price, to `decimals` precision
     */
    function latestPrice(
        PriceType /*priceType*/,
        MorigamiMath.Rounding /*roundingMode*/
    ) public override view returns (uint256 price) {
        return fixedPrice;
    }
}
