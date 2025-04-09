pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/investments/IMorigamiInvestmentVault.sol)

import { IMorigamiInvestment } from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import { IRepricingToken } from "contracts/interfaces/common/IRepricingToken.sol";

/**
 * @title Morigami Investment Vault
 * @notice A repricing Morigami Investment. Users invest in the underlying protocol and are allocated shares.
 * Morigami will apply the supplied token into the underlying protocol in the most optimal way.
 * The pricePerShare() will increase over time as upstream rewards are claimed by the protocol added to the reserves.
 * This makes the Morigami Investment Vault auto-compounding.
 */
interface IMorigamiInvestmentVault is IMorigamiInvestment, IRepricingToken {
    /**
     * @notice The performance fee which Morigami takes from harvested rewards before compounding into reserves.
     * Represented in basis points
     */
    function performanceFee() external view returns (uint256);
}
