pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/common/borrowAndLend/IMorigamiBorrowAndLend.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice An Morigami abstraction over a borrow/lend money market for
 * a single `supplyToken` and a multiple `borrowTokens`, for a given `positionOwner`
 */
interface IMorigamiBorrowAndLendMultiBorrowTokens {
    event PositionOwnerSet(address indexed account);
    event SurplusDebtReclaimed(uint256 amount, address indexed recipient);

    /**
     * @notice Set the position owner who can borrow/lend via this contract
     */
    function setPositionOwner(address account) external;

    /**
     * @notice Supply tokens as collateral
     */
    function supply(uint256 supplyAmount) external;

    /**
     * @notice Withdraw collateral tokens to recipient
     * @dev Set `withdrawAmount` to type(uint256).max in order to withdraw the whole balance
     */
    function withdraw(
        uint256 withdrawAmount,
        address recipient
    ) external returns (uint256 amountWithdrawn);

    /**
     * @notice Borrow tokens and send to recipient
     */
    function borrow(
        IERC20[] memory borrowTokens,
        uint256[] memory borrowAmounts,
        address recipient
    ) external;

    /**
     * @notice Repay debt.
     * @dev If `repayAmount` is set higher than the actual outstanding debt balance, it will be capped
     * to that outstanding debt balance
     * `debtRepaidAmount` return parameter will be capped to the outstanding debt balance.
     * Any surplus debtTokens (if debt fully repaid) will remain in this contract
     */
    function repay(
        IERC20 debtToken,
        uint256 repayAmount
    ) external returns (uint256 debtRepaidAmount);

    /**
     * @notice Repay debt and withdraw collateral in one step
     * @dev If `repayAmount` is set higher than the actual outstanding debt balance, it will be capped
     * to that outstanding debt balance
     * Set `withdrawAmount` to type(uint256).max in order to withdraw the whole balance
     * `debtRepaidAmount` return parameter will be capped to the outstanding debt amount.
     * Any surplus debtTokens (if debt fully repaid) will remain in this contract
     */
    function repayAndWithdraw(
        IERC20[] memory debtTokens,
        uint256[] memory repayAmounts,
        uint256 withdrawAmount,
        address recipient
    )
        external
        returns (uint256[] memory debtRepaidAmount, uint256 withdrawnAmount);

    /**
     * @notice Supply collateral and borrow in one step
     */
    function supplyAndBorrow(
        uint256 supplyAmount,
        IERC20[] memory debtTokens,
        uint256[] memory borrowAmounts,
        address recipient
    ) external;

    /**
     * @notice The approved owner of the borrow/lend position
     */
    function positionOwner() external view returns (address);

    /**
     * @notice The token supplied as collateral
     */
    function supplyToken() external view returns (address);

    /**
     * @notice The token which is borrowed
     */
    function borrowTokens() external view returns (address[] memory);

    /**
     * @notice The current (manually tracked) balance of tokens supplied
     */
    function suppliedBalance() external view returns (uint256);

    /**
     * @notice The current debt balance of particular `debtToken`
     */
    function debtBalance(address debtToken) external view returns (uint256);

    /**
     * @notice The current debt balances of tokens borrowed
     */
    function debtBalances() external view returns (uint256[] memory);

    /**
     * @notice Whether a given Assets/Liabilities Ratio is safe, given the upstream
     * money market parameters
     */
    function isSafeAlRatio(uint256 alRatio) external view returns (bool);

    /**
     * @notice How many `supplyToken` are available to withdraw from collateral
     * from the entire protocol, assuming this contract has fully paid down its debt
     */
    function availableToWithdraw() external view returns (uint256);

    /**
     * @notice How much more capacity is available to supply
     */
    function availableToSupply()
        external
        view
        returns (uint256 supplyCap, uint256 available);

    /**
     * @notice How many of particular `borrowToken` are available to borrow
     * from the entire protocol
     */
    function availableToBorrow(
        address borrowToken
    ) external view returns (uint256);
}
