pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiWstEthToEthOracle.sol)

import { IStETH } from "contracts/interfaces/external/lido/IStETH.sol";
import { IMorigamiOracle } from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import { MorigamiOracleBase } from "contracts/common/oracle/MorigamiOracleBase.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

/**
 * @title MorigamiWstEthToEthOracle
 * @notice The Lido wstETH/ETH oracle price, derived from the wstETH/stETH * stETH/ETH
 * where stETH/ETH ratio is pulled from the stETH contract's `getPooledEthByShares()`
 */
contract MorigamiWstEthToEthOracle is MorigamiOracleBase {
    using MorigamiMath for uint256;

    /**
     * @notice The (rebasing) Lido staked ETH contract (stETH)
     */
    IStETH public immutable stEth;

    /**
     * @notice The stETH/ETH oracle
     */
    IMorigamiOracle public immutable stEthToEthOracle;

    constructor (
        BaseOracleParams memory baseParams,
        address _stEth,
        address _stEthToEthOracle
    ) 
        MorigamiOracleBase(baseParams)
    {
        stEth = IStETH(_stEth);
        stEthToEthOracle = IMorigamiOracle(_stEthToEthOracle);
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
        // 1 wstETH to stETH
        price = stEth.getPooledEthByShares(precision);

        // Convert wstETH to ETH using the stEth/ETH oracle price
        price = price.mulDiv(
            stEthToEthOracle.latestPrice(priceType, roundingMode),
            precision,
            roundingMode
        );
    }
}
