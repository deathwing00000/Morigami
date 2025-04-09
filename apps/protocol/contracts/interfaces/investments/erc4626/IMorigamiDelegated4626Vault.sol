pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/erc4626/IMorigamiDelegated4626Vault.sol)

import { ITokenPrices } from "contracts/interfaces/common/ITokenPrices.sol";
import { IMorigamiErc4626 } from "contracts/interfaces/common/IMorigamiErc4626.sol";

/** 
 * @title Morigami Delegated ERC4626 Vault
 * @notice An Morigami ERC4626 Vault, which delegates the handling of deposited assets
 * to a manager
 */
interface IMorigamiDelegated4626Vault is IMorigamiErc4626 {
    event TokenPricesSet(address indexed _tokenPrices);
    event ManagerSet(address indexed manager);
    event PerformanceFeeSet(uint256 fee);

    /**
     * @notice Set the helper to calculate current off-chain/subgraph integration
     */
    function setTokenPrices(address tokenPrices) external;

    /**
     * @notice Set the Morigami delegated manager 
     */
    function setManager(address manager) external;

    /**
     * @notice The performance fee to Morigami treasury
     * Represented in basis points
     */
    function performanceFeeBps() external view returns (uint48);

    /**
     * @notice The helper contract to retrieve Morigami USD prices
     * @dev Required for off-chain/subgraph integration
     */
    function tokenPrices() external view returns (ITokenPrices);

    /**
     * @notice The Morigami contract managing the application of
     * the deposit tokens into the underlying protocol
     */
    function manager() external view returns (address);
}
