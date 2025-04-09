pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/investments/lending/IMorigamiLendingSupplyManager.sol)

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IWhitelisted } from "contracts/interfaces/common/access/IWhitelisted.sol";
import { IMorigamiCircuitBreakerProxy } from "contracts/interfaces/common/circuitBreaker/IMorigamiCircuitBreakerProxy.sol";
import { IMorigamiOTokenManager } from "contracts/interfaces/investments/IMorigamiOTokenManager.sol";
import { IMorigamiLendingClerk } from "contracts/interfaces/investments/lending/IMorigamiLendingClerk.sol";

/**
 * @title Morigami Lending Supply Manager
 * @notice Manages the deposits/exits into an Morigami oToken vault for lending purposes,
 * eg oUSDC. The supplied assets are forwarded onto a 'lending clerk' which manages the
 * collateral and debt
 * @dev supports an asset with decimals <= 18 decimal places
 */
interface IMorigamiLendingSupplyManager is IMorigamiOTokenManager, IWhitelisted {
    event LendingClerkSet(address indexed lendingClerk);
    event FeeCollectorSet(address indexed feeCollector);
    event ExitFeeBpsSet(uint256 feeBps);

    /**
     * @notice Set the clerk responsible for managing borrows, repays and debt of borrowers
     */
    function setLendingClerk(address _lendingClerk) external;

    /**
     * @notice Set the Morigami fee collector address
     */
    function setFeeCollector(address _feeCollector) external;

    /**
     * @notice Set the proportion of fees retained when users exit their position.
     * @dev represented in basis points
     */
    function setExitFeeBps(uint96 feeBps) external;

    /**
     * @notice The asset which users supply
     * eg USDC for oUSDC
     */
    function asset() external view returns (IERC20Metadata);

    /**
     * @notice The Morigami oToken which uses this manager
     */
    function oToken() external view returns (address);

    /**
     * @notice The Morigami ovToken which wraps the oToken
     */
    function ovToken() external view returns (address);

    /**
     * @notice A circuit breaker is used to ensure no more than a cap
     * is exited in a given period
     */
    function circuitBreakerProxy() external view returns (IMorigamiCircuitBreakerProxy);

    /**
     * @notice The clerk responsible for managing borrows, repays and debt of borrowers
     */
    function lendingClerk() external view returns (IMorigamiLendingClerk);

    /**
     * @notice The address used to collect the Morigami fees.
     */
    function feeCollector() external view returns (address);

    /**
     * @notice The proportion of fees retained when users exit their position.
     * @dev represented in basis points
     */
    function exitFeeBps() external view returns (uint96);
}
