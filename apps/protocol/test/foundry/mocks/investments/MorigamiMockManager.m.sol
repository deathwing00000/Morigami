pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {IMintableToken} from "contracts/interfaces/common/IMintableToken.sol";
import {IMorigamiOTokenManager} from "contracts/interfaces/investments/IMorigamiOTokenManager.sol";

import {MorigamiElevatedAccess} from "contracts/common/access/MorigamiElevatedAccess.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {MorigamiManagerPausable} from "contracts/investments/util/MorigamiManagerPausable.sol";

contract MorigamiMockManager is
    IMorigamiOTokenManager,
    MorigamiManagerPausable
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableToken;
    using MorigamiMath for uint256;

    /* solhint-disable immutable-vars-naming */
    IERC20 public immutable depositToken;
    IMintableToken public immutable oToken;
    address public immutable feeCollector;
    uint256 public sellFeeRate;

    constructor(
        address _initialOwner,
        address _oToken,
        address _depositToken,
        address _feeCollector,
        uint128 _sellFeeRate
    ) MorigamiElevatedAccess(_initialOwner) {
        oToken = IMintableToken(_oToken);
        depositToken = IERC20(_depositToken);
        feeCollector = _feeCollector;
        if (_sellFeeRate > MorigamiMath.BASIS_POINTS_DIVISOR)
            revert CommonEventsAndErrors.InvalidParam();
        sellFeeRate = _sellFeeRate;
    }

    function investWithToken(
        address /*account*/,
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external view override returns (uint256 investmentAmount) {
        if (_paused.investmentsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.fromToken != address(depositToken))
            revert CommonEventsAndErrors.InvalidToken(quoteData.fromToken);

        // User gets 1:1
        investmentAmount = quoteData.fromTokenAmount;
    }

    function exitToToken(
        address /*account*/,
        IMorigamiInvestment.ExitQuoteData memory quoteData,
        address recipient
    ) external override returns (uint256 toTokenAmount, uint256 toBurnAmount) {
        if (_paused.exitsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.investmentTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();
        if (quoteData.toToken != address(depositToken))
            revert CommonEventsAndErrors.InvalidToken(quoteData.toToken);

        (uint256 nonFees, uint256 fees) = quoteData
            .investmentTokenAmount
            .splitSubtractBps(sellFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        toTokenAmount = nonFees;

        if (fees != 0) {
            oToken.safeTransfer(feeCollector, fees);
        }

        if (nonFees != 0) {
            depositToken.safeTransfer(recipient, nonFees);

            // Burn the remaining
            toBurnAmount = nonFees;
        }
    }

    function baseToken() external view returns (address) {
        return address(depositToken);
    }

    function acceptedInvestTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        tokens = new address[](1);
        tokens[0] = address(depositToken);
    }

    function acceptedExitTokens()
        external
        view
        override
        returns (address[] memory tokens)
    {
        tokens = new address[](1);
        tokens[0] = address(depositToken);
    }

    /**
     * @notice Whether new investments are paused.
     */
    function areInvestmentsPaused() external view override returns (bool) {
        return _paused.investmentsPaused;
    }

    /**
     * @notice Whether exits are temporarily paused.
     */
    function areExitsPaused() external view override returns (bool) {
        return _paused.exitsPaused;
    }

    function investQuote(
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    )
        external
        view
        override
        returns (
            IMorigamiInvestment.InvestQuoteData memory quoteData,
            uint256[] memory investFeeBps
        )
    {
        if (fromToken != address(depositToken))
            revert CommonEventsAndErrors.InvalidToken(fromToken);
        if (fromTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();

        // minted 1:1, no fees or slippage
        quoteData = IMorigamiInvestment.InvestQuoteData({
            fromToken: fromToken,
            fromTokenAmount: fromTokenAmount,
            maxSlippageBps: maxSlippageBps,
            deadline: deadline,
            expectedInvestmentAmount: fromTokenAmount,
            minInvestmentAmount: fromTokenAmount,
            underlyingInvestmentQuoteData: "" // No extra underlyingInvestmentQuoteData
        });

        investFeeBps = new uint256[](0);
    }

    function exitQuote(
        uint256 investmentTokenAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    )
        external
        view
        override
        returns (
            IMorigamiInvestment.ExitQuoteData memory quoteData,
            uint256[] memory exitFeeBps
        )
    {
        if (investmentTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();
        if (toToken != address(depositToken))
            revert CommonEventsAndErrors.InvalidToken(toToken);

        uint256 _sellFeeRate = sellFeeRate;

        // sold 1:1, no slippage, with exit fee
        quoteData.investmentTokenAmount = investmentTokenAmount;
        quoteData.toToken = toToken;
        quoteData.maxSlippageBps = maxSlippageBps;
        quoteData.deadline = deadline;
        quoteData.expectedToTokenAmount = investmentTokenAmount.subtractBps(
            _sellFeeRate,
            MorigamiMath.Rounding.ROUND_DOWN
        );
        quoteData.minToTokenAmount = quoteData.expectedToTokenAmount;
        // No extra underlyingInvestmentQuoteData

        exitFeeBps = new uint256[](1);
        exitFeeBps[0] = _sellFeeRate;
    }

    /**
     * @notice The maximum amount of fromToken's that can be deposited
     * taking any other underlying protocol constraints into consideration
     */
    function maxInvest(
        address /*fromToken*/
    ) external pure override returns (uint256 amount) {
        amount = 123e18;
    }

    /**
     * @notice The maximum amount of tokens that can be exited into the toToken
     * taking any other underlying protocol constraints into consideration
     */
    function maxExit(
        address /*toToken*/
    ) external pure override returns (uint256 amount) {
        amount = 456e18;
    }
}
