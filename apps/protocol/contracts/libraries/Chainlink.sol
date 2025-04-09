pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (libraries/Chainlink.sol)

import { IAggregatorV3Interface } from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import { IMorigamiOracle } from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

/**
 * @notice A helper library to safely query prices from Chainlink oracles and scale them 
 * 
 * @dev Note this Chainlink lib is only suitable for mainnet. If a Chainlink Oracle is required on
 * an L2, then it should also take the sequencer staleness into consideration.
 * eg: https://docs.chain.link/data-feeds/l2-sequencer-feeds#example-code
 */
library Chainlink {
    using MorigamiMath for uint256;

    struct Config {
        IAggregatorV3Interface oracle;
        bool scaleDown;
        uint128 scalar;
        uint256 stalenessThreshold;
        bool validateRoundId;
        bool validateLastUpdatedAt;
    }

    /**
     * @notice Query a price from a Chainlink oracle interface and perform sanity checks
     * The oracle price is scaled to the expected Morigami precision (18dp)
     */
    function price(
        Config memory self,
        MorigamiMath.Rounding roundingMode
    ) internal view returns (uint256) {
        (uint80 roundId, int256 feedValue, , uint256 lastUpdatedAt,) = self.oracle.latestRoundData();

        // Invalid chainlink parameters
        if (self.validateRoundId && roundId == 0) revert IMorigamiOracle.InvalidOracleData(address(self.oracle));
        if (self.validateLastUpdatedAt) {
            if (lastUpdatedAt == 0) revert IMorigamiOracle.InvalidOracleData(address(self.oracle));

            // Check for future time or if it's too stale
            if (lastUpdatedAt > block.timestamp) revert IMorigamiOracle.InvalidOracleData(address(self.oracle));
            unchecked {
                if (block.timestamp - lastUpdatedAt > self.stalenessThreshold) {
                    revert IMorigamiOracle.StalePrice(address(self.oracle), lastUpdatedAt, feedValue);
                }
            }
        }

        // Check for negative price
        if (feedValue < 0) revert IMorigamiOracle.InvalidPrice(address(self.oracle), feedValue);

        return self.scaleDown 
            ? uint256(feedValue).scaleDown(self.scalar, roundingMode)
            : uint256(feedValue).scaleUp(self.scalar);
    }

    /**
     * @notice Calculate the scaling factor to convert the chainlink oracle decimals to
     * our targetDecimals (18dp)
     */
    function scalingFactor(
        IAggregatorV3Interface oracle,
        uint8 targetDecimals
    ) internal view returns (uint128 scalar, bool scaleDown) {
        uint8 oracleDecimals = oracle.decimals();

        unchecked {
            if (oracleDecimals <= targetDecimals) {
                // Scale up (no-op if sourcePrecision == pricePrecision)
                scalar = uint128(10) ** (targetDecimals - oracleDecimals);
            } else {
                // scale down
                scalar = uint128(10) ** (oracleDecimals - targetDecimals);
                scaleDown = true;
            }
        }
    }
}