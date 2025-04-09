pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/investments/lovToken/managers/IMorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens.sol)

import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IMorigamiLpPool} from "contracts/interfaces/common/lpTokensPool/IMorigamiLpPool.sol";
import {IMorigamiLovTokenManagerMultiBorrowTokens} from "contracts/interfaces/investments/lovToken/managers/IMorigamiLovTokenManagerMultiBorrowTokens.sol";
import {IMorigamiFlashLoanReceiverMultipleTokens} from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanReceiverMultipleTokens.sol";
import {IMorigamiFlashLoanProviderMultipleTokens} from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProviderMultipleTokens.sol";

/**
 * @title Morigami lovToken Manager
 * @notice The delegated logic to handle deposits/exits, and borrow/repay (rebalances) into the underlying reserve token
 */
interface IMorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens is
    IMorigamiLovTokenManagerMultiBorrowTokens,
    IMorigamiFlashLoanReceiverMultipleTokens
{
    event LpPoolSet(address indexed lpPool);
    event FlashLoanProviderSet(address indexed provider);
    event OraclesSet(
        address[] indexed debtTokenToReserveTokenOracles,
        address indexed dynamicFeePriceOracle
    );
    event BorrowLendSet(address indexed addr);
    event Rebalance(
        /// @dev positive when Morigami supplies the `reserveToken` as new collateral, negative when Morigami withdraws collateral
        /// Represented in the units of the `reserveToken` of this lovToken
        int256 collateralChange,
        /// @dev positive when Morigami borrows new debt, negative when Morigami repays debt
        /// Represented in the units of the `debtTokens` of this lovToken
        int256[] debtChanges,
        /// @dev The Assets/Liabilities ratio before the rebalance
        uint256 alRatioBefore,
        /// @dev The Assets/Liabilities ratio after the rebalance
        uint256 alRatioAfter
    );

    /**
     * @notice Set the lpPool responsible for `reserveToken` <--> `debtToken` minting/burning
     */
    function setLpPool(address _lpPool) external;

    /**
     * @notice Set the `reserveToken` <--> `debtToken` oracles configuration
     */
    function setOracles(
        address[] memory _debtTokenToReserveTokenOracles,
        address _dynamicFeePriceOracle
    ) external;

    /**
     * @notice Set the flash loan provider
     */
    function setFlashLoanProvider(address _provider) external;

    /**
     * @notice Set the Morigami Borrow/Lend position holder
     */
    function setBorrowLend(address _address) external;

    struct RebalanceUpParams {
        // The amount of `debtTokens` to flashloan, used to repay Aave/Spark debt
        uint256[] flashLoanAmounts;
        // The amount of `reserveToken` collateral to withdraw after debt is repaid
        uint256 collateralToWithdraw;
        // The lp pool data to add/remove liquidity
        bytes lpPoolData;
        // The min balance threshold for when surplus balance of `debtToken` is repaid to the Spark/Aave position
        uint256 repaySurplusThreshold;
        // The minimum acceptable A/L, will revert if below this
        uint128 minNewAL;
        // The maximum acceptable A/L, will revert if above this
        uint128 maxNewAL;
    }

    /**
     * @notice Increase the A/L by reducing liabilities. Flash loan and repay debt, and withdraw collateral to repay the flash loan
     */
    function rebalanceUp(RebalanceUpParams calldata params) external;

    /**
     * @notice Force a rebalanceUp ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceUp(RebalanceUpParams calldata params) external;

    struct RebalanceDownParams {
        // The amount of new `debtTokens` to flashloan
        uint256[] flashLoanAmounts;
        // The minimum amount of `reserveToken` expected when removing liquidity
        uint256 minExpectedReserveToken;
        // The lp pool data to add/remove liquidity
        bytes lpPoolData;
        // The minimum acceptable A/L, will revert if below this
        uint128 minNewAL;
        // The maximum acceptable A/L, will revert if above this
        uint128 maxNewAL;
    }

    /**
     * @notice Decrease the A/L by increasing liabilities. Flash loan `debtToken` swap to `reserveToken`
     * and add as collateral into Aave/Spark. Then borrow `debtToken` to repay the flash loan.
     */
    function rebalanceDown(RebalanceDownParams calldata params) external;

    /**
     * @notice Force a rebalanceDown ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceDown(RebalanceDownParams calldata params) external;

    /**
     * @notice The flashLoan provider contract, which may be through Aave/Spark/Balancer/etc
     */
    function flashLoanProvider()
        external
        view
        returns (IMorigamiFlashLoanProviderMultipleTokens);

    /**
     * @notice The swapper for `debtToken` <--> `reserveToken`
     */
    function lpPool() external view returns (IMorigamiLpPool);

    /**
     * @notice The oracles to convert `debtToken` <--> `reserveToken`
     */
    function debtTokenToReserveTokenOracles()
        external
        view
        returns (IMorigamiOracle[] memory);
}
