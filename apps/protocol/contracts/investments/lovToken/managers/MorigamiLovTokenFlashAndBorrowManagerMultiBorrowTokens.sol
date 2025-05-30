pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/lovToken/managers/MorigamiLovTokenMultiFlashAndBorrowManager.sol)

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens} from "contracts/interfaces/investments/lovToken/managers/IMorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {IMorigamiLpPool} from "contracts/interfaces/common/lpTokensPool/IMorigamiLpPool.sol";
import {IMorigamiLovTokenManagerMultiBorrowTokens} from "contracts/interfaces/investments/lovToken/managers/IMorigamiLovTokenManagerMultiBorrowTokens.sol";
import {IMorigamiFlashLoanProviderMultipleTokens} from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProviderMultipleTokens.sol";

import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {MorigamiAbstractLovTokenManagerMultiBorrowTokens} from "contracts/investments/lovToken/managers/MorigamiAbstractLovTokenManagerMultiBorrowTokens.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {Range} from "contracts/libraries/Range.sol";
import {DynamicFees} from "contracts/libraries/DynamicFees.sol";
import {IMorigamiBorrowAndLendMultiBorrowTokens} from "contracts/interfaces/common/borrowAndLend/IMorigamiBorrowAndLendMultiBorrowTokens.sol";
import {ICurveStableSwapNG} from "contracts/interfaces/external/curve/ICurveStableSwapNG.sol";
import {ICurvePool} from "contracts/interfaces/external/curve/ICurvePool.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {IMorigamiOTokenManager} from "contracts/interfaces/investments/IMorigamiOTokenManager.sol";

/**
 * @title Morigami LovToken Multi Flash And Borrow Manager
 * @notice The `reserveToken` is deposited by users and supplied into a money market as collateral
 * Upon a rebalanceDown (to decrease the A/L), `debtTokens` is borrowed (via a flashloan), provided as liquidity
 * to dexes(such as UniswapV2, Curve) where lp tokens is ERC20 which is `reserveToken` and added back in as more collateral.
 */
contract MorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens is
    IMorigamiLovTokenFlashAndBorrowManagerMultiBorrowTokens,
    MorigamiAbstractLovTokenManagerMultiBorrowTokens
{
    using SafeERC20 for IERC20;
    using MorigamiMath for uint256;

    /**
     * @notice reserveToken that this lovToken levers up on
     * This is also the asset which users deposit/exit with in this lovToken manager
     */
    IERC20 private immutable _reserveToken;

    bool private _checkForLock;

    /**
     * @notice The assets which lovToken borrows from the money market to increase the A/L ratio
     */
    IERC20[] private _debtTokens;

    /**
     * @notice The contract responsible for borrow/lend via external markets
     */
    IMorigamiBorrowAndLendMultiBorrowTokens public borrowLend;

    /**
     * @notice The Morigami flashLoan provider contract, which may be via Aave/Spark/Balancer/etc
     */
    IMorigamiFlashLoanProviderMultipleTokens public override flashLoanProvider;

    /**
     * @notice The lp pool for `debtTokens` <--> `reserveToken` mint/burn
     */
    IMorigamiLpPool public override lpPool;

    /**
     * @notice The oracle to convert `debtToken` <--> `reserveToken`
     */
    IMorigamiOracle[] private _debtTokenToReserveTokenOracles;

    /**
     * @dev Internal struct used to abi.encode params through a flashloan request
     */
    enum RebalanceCallbackType {
        REBALANCE_DOWN,
        REBALANCE_UP
    }

    /**
     * @dev if reserveToken is Curve LP token, then tokens in _debtTokens_ array should be equal to the
     * tokens in Curve Pool by indexes. If reserveToken is UniswapV2 LP token, then _debtTokens array
     * should contain 2 tokens - the tokens in the pair.
     */
    constructor(
        address _initialOwner,
        address _reserveToken_,
        IERC20[] memory _debtTokens_,
        address _lovToken,
        address _flashLoanProvider,
        address _borrowLend,
        bool checkForLock
    )
        MorigamiAbstractLovTokenManagerMultiBorrowTokens(
            _initialOwner,
            _lovToken
        )
    {
        _reserveToken = IERC20(_reserveToken_);

        _debtTokens = _debtTokens_;
        flashLoanProvider = IMorigamiFlashLoanProviderMultipleTokens(
            _flashLoanProvider
        );
        borrowLend = IMorigamiBorrowAndLendMultiBorrowTokens(_borrowLend);

        _checkForLock = checkForLock;
    }

    function investWithToken(
        address account,
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) public override(IMorigamiOTokenManager, MorigamiAbstractLovTokenManagerMultiBorrowTokens) returns (uint256) {
        if (_checkForLock) {
            ICurvePool(address(_reserveToken)).remove_liquidity_one_coin(
                0,
                0,
                0
            );
        }
        return MorigamiAbstractLovTokenManagerMultiBorrowTokens.investWithToken(account, quoteData);
    }

    function exitToToken(
        address account,
        IMorigamiInvestment.ExitQuoteData calldata quoteData,
        address recipient
    ) public override(IMorigamiOTokenManager, MorigamiAbstractLovTokenManagerMultiBorrowTokens) returns (uint256, uint256) {
        if (_checkForLock) {
            ICurvePool(address(_reserveToken)).remove_liquidity_one_coin(
                0,
                0,
                0
            );
        }
        return MorigamiAbstractLovTokenManagerMultiBorrowTokens.exitToToken(account, quoteData, recipient);
    }

    /**
     * @notice Set the lp token pool responsible for `debtTokens` <--> `reserveToken` burns/mints
     */
    function setLpPool(address _lpPool) external override onlyElevatedAccess {
        if (_lpPool == address(0))
            revert CommonEventsAndErrors.InvalidAddress(_lpPool);

        // Update the approval's for both `reserveToken` and `debtToken`
        address _oldLpPool = address(lpPool);
        if (_oldLpPool != address(0)) {
            _reserveToken.forceApprove(_oldLpPool, 0);
            for (uint256 i = 0; i < _debtTokens.length; ) {
                _debtTokens[i].forceApprove(_oldLpPool, 0);
                unchecked {
                    ++i;
                }
            }
        }
        _reserveToken.forceApprove(_lpPool, type(uint256).max);
        for (uint256 i = 0; i < _debtTokens.length; ) {
            _debtTokens[i].forceApprove(_lpPool, type(uint256).max);
            unchecked {
                ++i;
            }
        }

        emit LpPoolSet(_lpPool);
        lpPool = IMorigamiLpPool(_lpPool);
    }

    /**
     * @notice Set the `debtToken` <--> `reserveToken` oracle configuration
     */
    function setOracles(
        address[] memory __debtTokenToReserveTokenOracles,
        address // Disable dynamic fee pricing for this vault
    ) external override onlyElevatedAccess {
        if (__debtTokenToReserveTokenOracles.length != _debtTokens.length)
            revert CommonEventsAndErrors.InvalidParam();
        for (uint256 i = 0; i < __debtTokenToReserveTokenOracles.length; ) {
            _debtTokenToReserveTokenOracles[i] = _validatedOracle(
                __debtTokenToReserveTokenOracles[i],
                address(_reserveToken),
                address(_debtTokens[i])
            );
            unchecked {
                ++i;
            }
        }

        emit OraclesSet(__debtTokenToReserveTokenOracles, address(0));
    }

    /**
     * @notice Set the Morigami flash loan provider
     */
    function setFlashLoanProvider(
        address provider
    ) external override onlyElevatedAccess {
        if (provider == address(0))
            revert CommonEventsAndErrors.InvalidAddress(address(0));
        flashLoanProvider = IMorigamiFlashLoanProviderMultipleTokens(provider);
        emit FlashLoanProviderSet(provider);
    }

    /**
     * @notice Set the Morigami Borrow/Lend position holder
     */
    function setBorrowLend(
        address _address
    ) external override onlyElevatedAccess {
        if (_address == address(0))
            revert CommonEventsAndErrors.InvalidAddress(address(0));
        borrowLend = IMorigamiBorrowAndLendMultiBorrowTokens(_address);
        emit BorrowLendSet(_address);
    }

    /**
     * @notice Increase the A/L by reducing liabilities. Flash loan and repay debt, and withdraw collateral to repay the flash loan
     */
    function rebalanceUp(
        RebalanceUpParams calldata params
    ) external override onlyElevatedAccess {
        flashLoanProvider.flashLoan(
            _debtTokens,
            params.flashLoanAmounts,
            abi.encode(
                RebalanceCallbackType.REBALANCE_UP,
                false,
                abi.encode(params)
            )
        );
    }

    /**
     * @notice Force a rebalanceUp ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceUp(
        RebalanceUpParams calldata params
    ) external override onlyElevatedAccess {
        flashLoanProvider.flashLoan(
            _debtTokens,
            params.flashLoanAmounts,
            abi.encode(
                RebalanceCallbackType.REBALANCE_UP,
                true,
                abi.encode(params)
            )
        );
    }

    /**
     * @notice Decrease the A/L by increasing liabilities. Flash loan `debtToken` swap to `reserveToken`
     * and add as collateral into a money market. Then borrow `debtToken` to repay the flash loan.
     */
    function rebalanceDown(
        RebalanceDownParams calldata params
    ) external override onlyElevatedAccess {
        flashLoanProvider.flashLoan(
            _debtTokens,
            params.flashLoanAmounts,
            abi.encode(
                RebalanceCallbackType.REBALANCE_DOWN,
                false,
                abi.encode(params)
            )
        );
    }

    /**
     * @notice Force a rebalanceDown ignoring A/L ceiling/floor
     * @dev Separate function to above to have stricter control on who can force
     */
    function forceRebalanceDown(
        RebalanceDownParams calldata params
    ) external override onlyElevatedAccess {
        flashLoanProvider.flashLoan(
            _debtTokens,
            params.flashLoanAmounts,
            abi.encode(
                RebalanceCallbackType.REBALANCE_DOWN,
                true,
                abi.encode(params)
            )
        );
    }

    /**
     * @notice Recover accidental donations. `collateralSupplyToken` can only be recovered for amounts greater than the
     * internally tracked balance.
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external override onlyElevatedAccess {
        emit CommonEventsAndErrors.TokenRecovered(to, token, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function debtTokenToReserveTokenOracles()
        external
        view
        override
        returns (IMorigamiOracle[] memory)
    {
        return _debtTokenToReserveTokenOracles;
    }

    /**
     * @notice The total balance of reserve tokens this lovToken holds.
     */
    function reservesBalance()
        public
        view
        override(
            MorigamiAbstractLovTokenManagerMultiBorrowTokens,
            IMorigamiLovTokenManagerMultiBorrowTokens
        )
        returns (uint256)
    {
        return borrowLend.suppliedBalance();
    }

    /**
     * @notice The underlying token this investment wraps. In this case, it's the `reserveToken`
     */
    function baseToken() external view override returns (address) {
        return address(_reserveToken);
    }

    /**
     * @notice The set of accepted tokens which can be used to invest.
     * Only the `reserveToken` in this instance
     */
    function acceptedInvestTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        tokens = new address[](1);
        tokens[0] = address(_reserveToken);
    }

    /**
     * @notice The set of accepted tokens which can be used to exit into.
     * Only the `reserveToken` in this instance
     */
    function acceptedExitTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        tokens = new address[](1);
        tokens[0] = address(_reserveToken);
    }

    /**
     * @notice The reserveToken that the lovToken levers up on
     */
    function reserveToken()
        public
        view
        override(
            MorigamiAbstractLovTokenManagerMultiBorrowTokens,
            IMorigamiLovTokenManagerMultiBorrowTokens
        )
        returns (address)
    {
        return address(_reserveToken);
    }

    /**
     * @notice The assets which lovToken borrows to increase the A/L ratio
     */
    function debtTokens() external view override returns (address[] memory) {
        address[] memory _debtTokens_ = new address[](_debtTokens.length);
        for (uint256 i = 0; i < _debtTokens.length; ) {
            _debtTokens_[i] = address(_debtTokens[i]);
            unchecked {
                ++i;
            }
        }
        return _debtTokens_;
    }

    /**
     * @notice The debt of the lovToken to the money market, converted into the `reserveToken`
     * @dev Use the Oracle `debtPriceType` to value any debt in terms of the reserve token
     */
    function liabilities(
        IMorigamiOracle.PriceType debtPriceType
    )
        public
        view
        override(
            MorigamiAbstractLovTokenManagerMultiBorrowTokens,
            IMorigamiLovTokenManagerMultiBorrowTokens
        )
        returns (uint256)
    {
        // Convert the [debtTokens] into the [reserveToken] terms
        uint256 totalDebtInReserveToken = 0;
        for (uint256 i = 0; i < _debtTokens.length; ) {
            uint256 debt = borrowLend.debtBalance(address(_debtTokens[i]));
            if (debt == 0) continue;
            totalDebtInReserveToken += _debtTokenToReserveTokenOracles[i]
                .convertAmount(
                    address(_debtTokens[i]),
                    debt,
                    debtPriceType,
                    MorigamiMath.Rounding.ROUND_UP
                );
            unchecked {
                ++i;
            }
        }

        return totalDebtInReserveToken;
    }

    /**
     * @notice Invoked from IMorigamiFlashLoanProviderMultipleTokens once a flash loan is successfully
     * received, to the msg.sender of `flashLoan()`
     * @param tokens The ERC20 tokens which have been borrowed
     * @param amounts The amounts which have been borrowed
     * @param fees The flashloan fees (in the same token)
     * @param params Client specific abi encoded params which are passed through from the original `flashLoan()` call
     */
    function flashLoanCallback(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory fees,
        bytes calldata params
    ) external override returns (bool) {
        if (msg.sender != address(flashLoanProvider))
            revert CommonEventsAndErrors.InvalidAccess();
        for (uint256 i = 0; i < tokens.length; ) {
            if (address(tokens[i]) != address(_debtTokens[i]))
                revert CommonEventsAndErrors.InvalidToken(address(tokens[i]));
            unchecked {
                ++i;
            }
        }

        // Decode the type & params and call the relevant callback function.
        // Each function must result in the `amount + fee` sitting in this contract such that it can be
        // transferred back to the flash loan provider.
        (
            RebalanceCallbackType _rebalanceType,
            bool force,
            bytes memory _rebalanceParams
        ) = abi.decode(params, (RebalanceCallbackType, bool, bytes));

        if (_rebalanceType == RebalanceCallbackType.REBALANCE_DOWN) {
            RebalanceDownParams memory _rdParams = abi.decode(
                _rebalanceParams,
                (RebalanceDownParams)
            );
            _rebalanceDownFlashLoanCallback(
                tokens,
                amounts,
                fees,
                _rdParams,
                force
            );
        } else {
            RebalanceUpParams memory _ruParams = abi.decode(
                _rebalanceParams,
                (RebalanceUpParams)
            );
            _rebalanceUpFlashLoanCallback(
                tokens,
                amounts,
                fees,
                _ruParams,
                force
            );
        }

        // Transfer the total flashloan amount + fee back to the `flashLoanProvider` for repayment
        for (uint256 i = 0; i < tokens.length; ) {
            tokens[i].safeTransfer(msg.sender, amounts[i] + fees[i]);
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /**
     * @dev Handle the rebalanceUp once the flash loan amount has been received
     */
    function _rebalanceUpFlashLoanCallback(
        IERC20[] memory _debtTokens_,
        uint256[] memory flashLoanAmounts,
        uint256[] memory fees,
        RebalanceUpParams memory params,
        bool force
    ) internal {
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            if (flashLoanAmounts[i] != params.flashLoanAmounts[i])
                revert CommonEventsAndErrors.InvalidParam();
            unchecked {
                ++i;
            }
        }

        // Get the current A/L to check for oracle prices, and so we can compare that the new A/L is higher after the rebalance
        Cache memory cache = populateCache(
            IMorigamiOracle.PriceType.SPOT_PRICE
        );
        uint128 alRatioBefore = _assetToLiabilityRatio(cache);

        uint256[] memory totalDebtRepaidInToken = flashLoanAmounts;
        uint256[] memory flashRepayAmounts = new uint256[](
            flashLoanAmounts.length
        );
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            flashRepayAmounts[i] = flashLoanAmounts[i] + fees[i];
            unchecked {
                ++i;
            }
        }
        IMorigamiBorrowAndLendMultiBorrowTokens _borrowLend = borrowLend;

        // Repay the [debtToken]
        {
            for (uint256 i = 0; i < flashLoanAmounts.length; ) {
                _debtTokens_[i].safeTransfer(
                    address(_borrowLend),
                    flashLoanAmounts[i]
                );
                unchecked {
                    ++i;
                }
            }
            // No need to check the withdrawnAmount returned, the amount passed in can never be type(uint256).max, so this will
            // be the exact `amount`
            (
                uint256[] memory amountsRepaid,
                uint256 withdrawnAmount
            ) = _borrowLend.repayAndWithdraw(
                    _debtTokens_,
                    flashLoanAmounts,
                    params.collateralToWithdraw,
                    address(this)
                );
            if (withdrawnAmount != params.collateralToWithdraw) {
                revert CommonEventsAndErrors.InvalidAmount(
                    address(_reserveToken),
                    params.collateralToWithdraw
                );
            }

            // Repaying less than what was asked is only allowed in force mode.
            // This will only happen when there is no more debt in the money market, ie we are fully delevered
            for (uint256 i = 0; i < flashLoanAmounts.length; ) {
                if (amountsRepaid[i] != flashLoanAmounts[i]) {
                    if (!force)
                        revert CommonEventsAndErrors.InvalidAmount(
                            address(_debtTokens_[i]),
                            flashLoanAmounts[i]
                        );
                    totalDebtRepaidInToken[i] = amountsRepaid[i];
                }
                unchecked {
                    ++i;
                }
            }
        }

        // Burn [reserveToken] as lp tokens to get [debtTokens]
        // The expected amount of [debtTokens] received after burning [reserveToken]
        // needs to at least cover the total flash loan amount + fee
        {
            uint256[] memory balancesBefore = new uint256[](
                flashLoanAmounts.length
            );
            for (uint256 i = 0; i < flashLoanAmounts.length; ) {
                balancesBefore[i] = _debtTokens_[i].balanceOf(address(this));
                unchecked {
                    ++i;
                }
            }
            lpPool.execute(
                _reserveToken,
                _debtTokens_,
                flashRepayAmounts,
                params.collateralToWithdraw,
                IMorigamiLpPool.Action.Remove,
                params.lpPoolData
            );
            for (uint256 i = 0; i < flashLoanAmounts.length; ) {
                if (
                    _debtTokens_[i].balanceOf(address(this)) -
                        balancesBefore[i] <
                    flashRepayAmounts[i]
                ) {
                    revert CommonEventsAndErrors
                        .InvalidAmountAfterLpIntercation(
                            address(_debtTokens_[i]),
                            flashRepayAmounts[i],
                            _debtTokens_[i].balanceOf(address(this)) -
                                balancesBefore[i]
                        );
                }
                unchecked {
                    ++i;
                }
            }
        }

        // If over the threshold, return any surplus [debtToken] from the swap to the borrowLend
        // And pay down residual debt
        {
            for (uint256 i = 0; i < flashLoanAmounts.length; ) {
                uint256 surplusAfterBurn = _debtTokens_[i].balanceOf(
                    address(this)
                ) - flashRepayAmounts[i];
                uint256 borrowLendSurplus = _debtTokens_[i].balanceOf(
                    address(_borrowLend)
                );
                if (
                    borrowLendSurplus + surplusAfterBurn >
                    params.repaySurplusThreshold
                ) {
                    if (surplusAfterBurn != 0) {
                        _debtTokens_[i].safeTransfer(
                            address(_borrowLend),
                            surplusAfterBurn
                        );
                    }
                    totalDebtRepaidInToken[i] =
                        totalDebtRepaidInToken[i] +
                        _borrowLend.repay(
                            _debtTokens_[i],
                            borrowLendSurplus + surplusAfterBurn
                        );
                }
                unchecked {
                    ++i;
                }
            }
        }

        // Validate that the new A/L is still within the `rebalanceALRange` and expected slippage range
        uint128 alRatioAfter = _validateAfterRebalance(
            cache,
            alRatioBefore,
            params.minNewAL,
            params.maxNewAL,
            AlValidationMode.HIGHER_THAN_BEFORE,
            force
        );

        int256[] memory totalDebtRepaidInTokenInt = new int256[](
            flashLoanAmounts.length
        );
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            totalDebtRepaidInTokenInt[i] = -int256(totalDebtRepaidInToken[i]);
            unchecked {
                ++i;
            }
        }
        emit Rebalance(
            -int256(params.collateralToWithdraw),
            totalDebtRepaidInTokenInt,
            alRatioBefore,
            alRatioAfter
        );
    }

    /**
     * @dev Handle the rebalanceDown once the flash loan amount has been received
     */
    function _rebalanceDownFlashLoanCallback(
        IERC20[] memory _debtTokens_,
        uint256[] memory flashLoanAmounts,
        uint256[] memory fees,
        RebalanceDownParams memory params,
        bool force
    ) internal {
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            if (flashLoanAmounts[i] != params.flashLoanAmounts[i])
                revert CommonEventsAndErrors.InvalidParam();
            unchecked {
                ++i;
            }
        }

        // Get the current A/L to check for oracle prices, and so we can compare that the new A/L is lower after the rebalance
        Cache memory cache = populateCache(
            IMorigamiOracle.PriceType.SPOT_PRICE
        );
        uint128 alRatioBefore = _assetToLiabilityRatio(cache);

        // Swap from the `debtToken` to the `reserveToken`,
        // based on the quotes obtained off chain
        uint256 balanceBefore = _reserveToken.balanceOf(address(this));
        lpPool.execute(
            _reserveToken,
            _debtTokens_,
            flashLoanAmounts,
            params.minExpectedReserveToken,
            IMorigamiLpPool.Action.Add,
            params.lpPoolData
        );
        uint256 collateralSupplied = _reserveToken.balanceOf(address(this)) -
            balanceBefore;

        if (collateralSupplied < params.minExpectedReserveToken) {
            revert CommonEventsAndErrors.InvalidAmountAfterLpIntercation(
                address(_reserveToken),
                params.minExpectedReserveToken,
                collateralSupplied
            );
        }

        // Supply `reserveToken` into the money market, and borrow `debtToken`
        uint256[] memory borrowAmounts = new uint256[](flashLoanAmounts.length);
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            borrowAmounts[i] = flashLoanAmounts[i] + fees[i];
            unchecked {
                ++i;
            }
        }
        IMorigamiBorrowAndLendMultiBorrowTokens _borrowLend = borrowLend;
        _reserveToken.safeTransfer(address(_borrowLend), collateralSupplied);

        _borrowLend.supplyAndBorrow(
            collateralSupplied,
            _debtTokens_,
            borrowAmounts,
            address(this)
        );

        // Validate that the new A/L is still within the `rebalanceALRange` and expected slippage range
        uint128 alRatioAfter = _validateAfterRebalance(
            cache,
            alRatioBefore,
            params.minNewAL,
            params.maxNewAL,
            AlValidationMode.LOWER_THAN_BEFORE,
            force
        );

        int256[] memory borrowAmountsInt = new int256[](
            flashLoanAmounts.length
        );
        for (uint256 i = 0; i < flashLoanAmounts.length; ) {
            borrowAmountsInt[i] = int256(borrowAmounts[i]);
            unchecked {
                ++i;
            }
        }
        emit Rebalance(
            int256(collateralSupplied),
            borrowAmountsInt,
            alRatioBefore,
            alRatioAfter
        );
    }

    /**
     * @notice The current deposit fee based on market conditions.
     * Deposit fees are applied to the portion of lovToken shares the depositor
     * would have received. Instead that fee portion isn't minted (benefiting remaining users)
     * In Morigami LovToken Flash And Borrow Manager, we don't charge any deposit fees because it will be
     * used only by More Vaults and there shouldn't be any economic attack, when there is only one actor
     * @dev represented in basis points
     */
    function _dynamicDepositFeeBps() internal pure override returns (uint256) {
        return 0;
    }

    /**
     * @notice The current exit fee based on market conditions.
     * Exit fees are applied to the lovToken shares the user is exiting.
     * That portion is burned prior to being redeemed (benefiting remaining users)
     * In Morigami LovToken Flash And Borrow Manager, we don't charge any exit fees because it will be
     * used only by More Vaults and there shouldn't be any economic attack, when there is only one actor
     * @dev represented in basis points
     */
    function _dynamicExitFeeBps() internal pure override returns (uint256) {
        return 0;
    }

    /**
     * @notice Deposit a number of `fromToken` into the `reserveToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _depositIntoReserves(
        address fromToken,
        uint256 fromTokenAmount
    ) internal override returns (uint256 newReservesAmount) {
        if (fromToken == address(_reserveToken)) {
            newReservesAmount = fromTokenAmount;

            // Supply into the money market
            IMorigamiBorrowAndLendMultiBorrowTokens _borrowLend = borrowLend;
            _reserveToken.safeTransfer(address(_borrowLend), fromTokenAmount);
            _borrowLend.supply(fromTokenAmount);
        } else {
            revert CommonEventsAndErrors.InvalidToken(fromToken);
        }
    }

    /**
     * @notice Calculate the amount of `reserveToken` will be deposited given an amount of `fromToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _previewDepositIntoReserves(
        address fromToken,
        uint256 fromTokenAmount
    ) internal view override returns (uint256 newReservesAmount) {
        return fromToken == address(_reserveToken) ? fromTokenAmount : 0;
    }

    /**
     * @notice Maximum amount of `fromToken` that can be deposited into the `reserveToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _maxDepositIntoReserves(
        address fromToken
    ) internal view override returns (uint256 fromTokenAmount) {
        if (fromToken == address(_reserveToken)) {
            (uint256 _supplyCap, uint256 _available) = borrowLend
                .availableToSupply();
            return _supplyCap == 0 ? MAX_TOKEN_AMOUNT : _available;
        }

        // Anything else returns 0
    }

    /**
     * @notice Calculate the number of `toToken` required in order to mint a given number of `reserveToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _previewMintReserves(
        address toToken,
        uint256 reservesAmount
    ) internal view override returns (uint256 newReservesAmount) {
        return toToken == address(_reserveToken) ? reservesAmount : 0;
    }

    /**
     * @notice Redeem a number of `reserveToken` into `toToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _redeemFromReserves(
        uint256 reservesAmount,
        address toToken,
        address recipient
    ) internal override returns (uint256 toTokenAmount) {
        if (toToken == address(_reserveToken)) {
            toTokenAmount = reservesAmount;
            uint256 _amountWithdrawn = borrowLend.withdraw(
                reservesAmount,
                recipient
            );
            if (_amountWithdrawn != reservesAmount)
                revert CommonEventsAndErrors.InvalidAmount(
                    toToken,
                    reservesAmount
                );
        } else {
            revert CommonEventsAndErrors.InvalidToken(toToken);
        }
    }

    /**
     * @notice Calculate the number of `toToken` recevied if redeeming a number of `reserveToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     */
    function _previewRedeemFromReserves(
        uint256 reservesAmount,
        address toToken
    ) internal view override returns (uint256 toTokenAmount) {
        return toToken == address(_reserveToken) ? reservesAmount : 0;
    }

    /**
     * @notice Maximum amount of `reserveToken` that can be redeemed to `toToken`
     * This vault only accepts where `fromToken` == `reserveToken`
     * @dev If the A/L is now unsafe (eg if the money market Liquidation LTV is now lower than the floor)
     * Then this will return zero
     */
    function _maxRedeemFromReserves(
        address toToken,
        Cache memory cache
    ) internal view override returns (uint256 reservesAmount) {
        // If the A/L range is invalid, then return 0
        IMorigamiBorrowAndLendMultiBorrowTokens _borrowLend = borrowLend;
        if (!_borrowLend.isSafeAlRatio(convertedAL(userALRange.floor, cache)))
            return 0;

        if (toToken == address(_reserveToken)) {
            // The max number of reserveToken available for redemption is the minimum
            // of our position (the reserves balance) and what's available to withdraw from the money market (the balance
            // of the reserve token within the collateralSupplyToken)
            uint256 _reservesBalance = _borrowLend.suppliedBalance();
            uint256 _availableInAave = _borrowLend.availableToWithdraw();
            reservesAmount = _reservesBalance < _availableInAave
                ? _reservesBalance
                : _availableInAave;
        }

        // Anything else returns 0
    }

    /**
     * @dev Revert if the range is invalid comparing to upstrea Aave/Spark
     */
    function _validateAlRange(Range.Data storage range) internal view override {
        if (!borrowLend.isSafeAlRatio(range.floor))
            revert Range.InvalidRange(range.floor, range.ceiling);
    }

    function _validatedOracle(
        address oracleAddress,
        address baseAsset,
        address quoteAsset
    ) private view returns (IMorigamiOracle oracle) {
        if (oracleAddress == address(0))
            revert CommonEventsAndErrors.InvalidAddress(address(0));
        oracle = IMorigamiOracle(oracleAddress);

        // Validate the assets on the oracle match what this lovToken needs
        if (!oracle.matchAssets(baseAsset, quoteAsset)) {
            revert CommonEventsAndErrors.InvalidParam();
        }
    }
}
