pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/borrowAndLend/MorigamiAaveV3BorrowAndLendMultiBorrowTokens.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {WadRayMath as AaveWadRayMath} from "@aave/core-v3/contracts/protocol/libraries/math/WadRayMath.sol";
import {ReserveConfiguration as AaveReserveConfiguration} from "@aave/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol";
import {DataTypes as AaveDataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool as IAavePool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken as IAaveAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {IAaveV3RewardsController} from "contracts/interfaces/external/aave/aave-v3-periphery/IAaveV3RewardsController.sol";

import {IMorigamiAaveV3BorrowAndLendMultiBorrowTokens} from "contracts/interfaces/common/borrowAndLend/IMorigamiAaveV3BorrowAndLendMultiBorrowTokens.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {MorigamiElevatedAccess} from "contracts/common/access/MorigamiElevatedAccess.sol";

/**
 * @notice An Morigami abstraction over a borrow/lend money market for
 * a single `supplyToken` and a multiple `_borrowTokens`.
 * This is an Aave V3 specific interface, borrowing using variable debt only
 */
contract MorigamiAaveV3BorrowAndLendMultiBorrowTokens is
    IMorigamiAaveV3BorrowAndLendMultiBorrowTokens,
    MorigamiElevatedAccess
{
    using SafeERC20 for IERC20;
    using AaveReserveConfiguration for AaveDataTypes.ReserveConfigurationMap;

    /**
     * @notice The Aave/Spark pool contract
     */
    IAavePool public override aavePool;

    /**
     * @notice The token supplied as collateral
     */
    address public immutable override supplyToken;

    /**
     * @notice The token which is borrowed
     */
    address[] public _borrowTokens;

    /**
     * @notice The Aave/Spark rebasing aToken received when supplying `supplyToken`
     */
    IAaveAToken public immutable override aaveAToken;

    /**
     * @notice The Aave/Spark rebasing variable debt token received when borrowing `debtToken`
     */
    IERC20Metadata[] public _aaveDebtTokens;

    /**
     * @notice The approved owner of the borrow/lend position
     */
    address public override positionOwner;

    /**
     * @notice Only use the Aave/Spark variable interest, not fixed
     */
    uint256 private constant INTEREST_RATE_MODE =
        uint256(AaveDataTypes.InterestRateMode.VARIABLE);

    /**
     * @notice The referral code used when supplying/borrowing in Aave/Spark
     */
    uint16 public override referralCode = 0;

    /**
     * @dev The number of Aave/Spark aToken shares are tracked manually rather than relying on
     * balanceOf
     */
    uint256 private _aTokenShares;

    /**
     * @dev Factor when converting the Aave LTV (basis points) to an Morigami Assets/Liabilities (1e18)
     */
    uint256 private constant LTV_TO_AL_FACTOR = 1e22;

    constructor(
        address _initialOwner,
        address _supplyToken,
        address[] memory borrowTokens_,
        address _aavePool,
        uint8 _defaultEMode
    ) MorigamiElevatedAccess(_initialOwner) {
        supplyToken = _supplyToken;
        _borrowTokens = borrowTokens_;

        aavePool = IAavePool(_aavePool);
        aaveAToken = IAaveAToken(
            aavePool.getReserveData(supplyToken).aTokenAddress
        );
        for (uint256 i = 0; i < borrowTokens_.length; ) {
            _aaveDebtTokens[i] = IERC20Metadata(
                aavePool
                    .getReserveData(borrowTokens_[i])
                    .variableDebtTokenAddress
            );
            unchecked {
                ++i;
            }
        }

        // Approve the supply and borrow to the Aave/Spark pool upfront
        IERC20(supplyToken).forceApprove(address(aavePool), type(uint256).max);
        for (uint256 i = 0; i < borrowTokens_.length; ) {
            IERC20(_borrowTokens[i]).forceApprove(
                address(aavePool),
                type(uint256).max
            );
            unchecked {
                ++i;
            }
        }

        // Initate e-mode on the Aave/Spark pool if required
        if (_defaultEMode != 0) {
            aavePool.setUserEMode(_defaultEMode);
        }
    }

    /**
     * @notice Set the position owner who can borrow/lend via this contract
     */
    function setPositionOwner(
        address account
    ) external override onlyElevatedAccess {
        positionOwner = account;
        emit PositionOwnerSet(account);
    }

    /**
     * @notice Set the Aave/Spark referral code
     */
    function setReferralCode(uint16 code) external override onlyElevatedAccess {
        referralCode = code;
        emit ReferralCodeSet(code);
    }

    /**
     * @notice Allow the use of `supplyToken` as collateral within Aave/Spark
     */
    function setUserUseReserveAsCollateral(
        bool useAsCollateral
    ) external override onlyElevatedAccess {
        aavePool.setUserUseReserveAsCollateral(supplyToken, useAsCollateral);
    }

    /**
     * @notice Update the e-mode category for the pool
     */
    function setEModeCategory(
        uint8 categoryId
    ) external override onlyElevatedAccess {
        aavePool.setUserEMode(categoryId);
    }

    /**
     * @notice Update the Aave/Spark pool
     */
    function setAavePool(address pool) external override onlyElevatedAccess {
        if (pool == address(0))
            revert CommonEventsAndErrors.InvalidAddress(pool);

        address oldPool = address(aavePool);
        if (pool == oldPool) revert CommonEventsAndErrors.InvalidAddress(pool);

        emit AavePoolSet(pool);
        aavePool = IAavePool(pool);

        // Reset allowance to old Aave/Spark pool
        IERC20(supplyToken).forceApprove(oldPool, 0);
        for (uint256 i = 0; i < _borrowTokens.length; ) {
            IERC20(_borrowTokens[i]).forceApprove(oldPool, 0);
            unchecked {
                ++i;
            }
        }

        // Approve the supply and borrow to the new Aave/Spark pool upfront
        IERC20(supplyToken).forceApprove(pool, type(uint256).max);
        for (uint256 i = 0; i < _borrowTokens.length; ) {
            IERC20(_borrowTokens[i]).forceApprove(pool, type(uint256).max);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Elevated access can claim rewards, from a nominated rewards controller.
     * @param rewardsController The aave-v3-periphery RewardsController
     * @param assets The list of assets to check eligible distributions before claiming rewards
     * @param to The address that will be receiving the rewards
     * @return rewardsList List of addresses of the reward tokens
     * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardList"
     */
    function claimAllRewards(
        address rewardsController,
        address[] calldata assets,
        address to
    )
        external
        override
        onlyElevatedAccess
        returns (address[] memory rewardsList, uint256[] memory claimedAmounts)
    {
        // Event emitted within rewards controller.
        return
            IAaveV3RewardsController(rewardsController).claimAllRewards(
                assets,
                to
            );
    }

    /**
     * @notice Supply tokens as collateral
     */
    function supply(
        uint256 supplyAmount
    ) external override onlyPositionOwnerOrElevated {
        _supply(supplyAmount);
    }

    /**
     * @notice Withdraw collateral tokens to recipient
     * @dev Set `withdrawAmount` to type(uint256).max in order to withdraw the whole balance
     */
    function withdraw(
        uint256 withdrawAmount,
        address recipient
    )
        external
        override
        onlyPositionOwnerOrElevated
        returns (uint256 amountWithdrawn)
    {
        amountWithdrawn = _withdraw(withdrawAmount, recipient);
    }

    /**
     * @notice Borrow tokens and send to recipient
     */
    function borrow(
        IERC20[] memory borrowTokens_,
        uint256[] memory _borrowAmounts,
        address recipient
    ) external override onlyPositionOwnerOrElevated {
        _borrow(borrowTokens_, _borrowAmounts, recipient);
    }

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
    )
        external
        override
        onlyPositionOwnerOrElevated
        returns (uint256 debtRepaidAmount)
    {
        debtRepaidAmount = _repay(debtToken, repayAmount);
    }

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
        override
        onlyPositionOwnerOrElevated
        returns (uint256[] memory debtRepaidAmount, uint256 withdrawnAmount)
    {
        debtRepaidAmount = _repay(debtTokens, repayAmounts);
        withdrawnAmount = _withdraw(withdrawAmount, recipient);
    }

    /**
     * @notice Supply collateral and borrow in one step
     */
    function supplyAndBorrow(
        uint256 supplyAmount,
        IERC20[] memory borrowTokens_,
        uint256[] memory _borrowAmounts,
        address recipient
    ) external override onlyPositionOwnerOrElevated {
        _supply(supplyAmount);
        _borrow(borrowTokens_, _borrowAmounts, recipient);
    }

    /**
     * @notice Recover accidental donations, or surplus aaveAToken borrowToken.
     * `aaveAToken` can only be recovered for amounts greater than the internally tracked balance of shares.
     * `borrowToken` are only expected on shutdown if there are surplus tokens after full repayment.
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyElevatedAccess {
        emit CommonEventsAndErrors.TokenRecovered(to, token, amount);
        IERC20(token).safeTransfer(to, amount);

        if (token == address(aaveAToken)) {
            // Ensure there are still enough aToken shares to cover the internally tracked
            // balance
            uint256 _sharesAfter = aaveAToken.scaledBalanceOf(address(this));
            if (_aTokenShares > _sharesAfter) {
                revert CommonEventsAndErrors.InvalidAmount(token, amount);
            }
        }
    }

    /**
     * @notice The array of debt tokens which are borrowed
     */
    function aaveDebtTokens()
        external
        view
        override
        returns (IERC20Metadata[] memory)
    {
        return _aaveDebtTokens;
    }

    /**
     * @notice The array of tokens which are borrowed
     */
    function borrowTokens() external view override returns (address[] memory) {
        return _borrowTokens;
    }

    /**
     * @notice The current (manually tracked) balance of tokens supplied
     */
    function suppliedBalance() public view override returns (uint256) {
        return
            AaveWadRayMath.rayMul(
                _aTokenShares,
                aavePool.getReserveNormalizedIncome(supplyToken)
            );
    }

    /**
     * @notice The current debt balances of tokens borrowed
     */
    function debtBalances()
        public
        view
        override
        returns (uint256[] memory _debtBalances)
    {
        _debtBalances = new uint256[](_aaveDebtTokens.length);
        for (uint256 i = 0; i < _aaveDebtTokens.length; ) {
            _debtBalances[i] = _aaveDebtTokens[i].balanceOf(address(this));
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice The current debt balances of tokens borrowed
     */
    function debtBalance(
        address debtToken_
    ) public view override returns (uint256) {
        for (uint256 i = 0; i < _borrowTokens.length; ) {
            if (debtToken_ == _borrowTokens[i])
                return _aaveDebtTokens[i].balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        return 0;
    }

    /**
     * @notice Whether a given Assets/Liabilities Ratio is safe, given the upstream
     * money market parameters
     */
    function isSafeAlRatio(
        uint256 alRatio
    ) external view override returns (bool) {
        // If in e-mode, then use the LTV from that category
        // Otherwise use the LTV from the reserve data
        uint256 _eModeId = aavePool.getUserEMode(address(this));

        // Our max LTV must be <= Aave's deposits LTV (not the liquidation LTV)
        uint256 _aaveLtv = _eModeId == 0
            ? aavePool.getConfiguration(supplyToken).getLtv()
            : aavePool.getEModeCategoryData(uint8(_eModeId)).ltv;

        // Convert the Aave LTV to A/L (with 1e18 precision) and compare
        // The A/L is considered safe if it's higher or equal to the upstream aave A/L
        unchecked {
            return alRatio >= LTV_TO_AL_FACTOR / _aaveLtv;
        }
    }

    /**
     * @notice How many `supplyToken` are available to withdraw from collateral
     * from the entire protocol, assuming this contract has fully paid down its debt
     */
    function availableToWithdraw() external view override returns (uint256) {
        return IERC20(supplyToken).balanceOf(address(aaveAToken));
    }

    /**
     * @notice How many of particular`borrowToken` are available to borrow
     * from the entire protocol
     */
    function availableToBorrow(
        address _borrowToken
    ) external view override returns (uint256 available) {
        AaveDataTypes.ReserveData memory _reserveData = aavePool.getReserveData(
            _borrowToken
        );
        uint256 borrowCap = _reserveData.configuration.getBorrowCap() *
            (10 ** _reserveData.configuration.getDecimals());
        available = IERC20(_borrowToken).balanceOf(_reserveData.aTokenAddress);

        if (borrowCap > 0 && borrowCap < available) {
            available = borrowCap;
        }
    }

    /**
     * @notice How much more capacity is available to supply
     */
    function availableToSupply()
        external
        view
        override
        returns (uint256 supplyCap, uint256 available)
    {
        AaveDataTypes.ReserveData memory _reserveData = aavePool.getReserveData(
            supplyToken
        );

        // The supply cap needs to be scaled by decimals
        uint256 unscaledCap = _reserveData.configuration.getSupplyCap();
        if (unscaledCap == 0) return (type(uint256).max, type(uint256).max);
        supplyCap =
            unscaledCap *
            (10 ** _reserveData.configuration.getDecimals());

        // The utilised amount is the scaledTotalSupply + any fees accrued to treasury
        // Then scaled by the normalised income.
        uint256 _utilised = AaveWadRayMath.rayMul(
            aavePool.getReserveNormalizedIncome(supplyToken),
            (aaveAToken.scaledTotalSupply() + _reserveData.accruedToTreasury)
        );

        unchecked {
            available = supplyCap > _utilised ? supplyCap - _utilised : 0;
        }
    }

    /**
     * @notice Returns the Aave/Spark account data
     * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
     * @return totalDebtBase The total debt of the user in the base currency used by the price feed
     * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of The user
     * @return healthFactor The current health factor of the user
     */
    function debtAccountData()
        external
        view
        override
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return aavePool.getUserAccountData(address(this));
    }

    function _supply(uint256 supplyAmount) internal {
        uint256 sharesBefore = aaveAToken.scaledBalanceOf(address(this));
        aavePool.supply(supplyToken, supplyAmount, address(this), referralCode);
        _aTokenShares =
            _aTokenShares +
            aaveAToken.scaledBalanceOf(address(this)) -
            sharesBefore;
    }

    function _withdraw(
        uint256 withdrawAmount,
        address recipient
    ) internal returns (uint256 amountWithdrawn) {
        uint256 sharesBefore = aaveAToken.scaledBalanceOf(address(this));
        amountWithdrawn = aavePool.withdraw(
            supplyToken,
            withdrawAmount,
            recipient
        );
        _aTokenShares =
            _aTokenShares +
            aaveAToken.scaledBalanceOf(address(this)) -
            sharesBefore;
    }

    function _borrow(
        IERC20[] memory borrowTokens_,
        uint256[] memory _borrowAmounts,
        address recipient
    ) internal {
        for (uint256 i = 0; i < borrowTokens_.length; ) {
            _validateBorrowToken(address(borrowTokens_[i]));
            aavePool.borrow(
                address(borrowTokens_[i]),
                _borrowAmounts[i],
                INTEREST_RATE_MODE,
                referralCode,
                address(this)
            );
            borrowTokens_[i].safeTransfer(recipient, _borrowAmounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _repay(
        IERC20 _debtToken,
        uint256 _repayAmount
    ) internal returns (uint256 debtRepaidAmount) {
        _validateBorrowToken(address(_debtToken));
        if (debtBalance(address(_debtToken)) != 0) {
            debtRepaidAmount = aavePool.repay(
                address(_debtToken),
                _repayAmount,
                INTEREST_RATE_MODE,
                address(this)
            );
        }
    }

    function _repay(
        IERC20[] memory _debtTokens,
        uint256[] memory _repayAmounts
    ) internal returns (uint256[] memory debtRepaidAmount) {
        debtRepaidAmount = new uint256[](_debtTokens.length);
        for (uint256 i = 0; i < _debtTokens.length; ) {
            debtRepaidAmount[i] = _repay(_debtTokens[i], _repayAmounts[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _validateBorrowToken(address _borrowToken) internal view {
        for (uint256 i = 0; i < _borrowTokens.length; ) {
            if (_borrowToken == _borrowTokens[i]) return;
            unchecked {
                ++i;
            }
        }
        revert CommonEventsAndErrors.InvalidToken(_borrowToken);
    }
    /**
     * @dev Only the positionOwner or Elevated Access is allowed to call.
     */
    modifier onlyPositionOwnerOrElevated() {
        if (msg.sender != address(positionOwner)) {
            if (!isElevatedAccess(msg.sender, msg.sig))
                revert CommonEventsAndErrors.InvalidAccess();
        }
        _;
    }
}
