pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMintableToken} from "contracts/interfaces/common/IMintableToken.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {IMorigamiOTokenManagerWithNative} from "contracts/interfaces/investments/IMorigamiOTokenManagerWithNative.sol";
import {MorigamiMockManager} from "test/foundry/mocks/investments/MorigamiMockManager.m.sol";

import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";

contract MorigamiMockManagerWithNative is
    MorigamiMockManager,
    IMorigamiOTokenManagerWithNative
{
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableToken;
    using MorigamiMath for uint256;

    /* solhint-disable immutable-vars-naming */
    address public immutable override wrappedNativeToken;

    constructor(
        address _initialOwner,
        address _oToken,
        address _wrappedNativeToken,
        address _feeCollector,
        uint128 _sellFeeNumerator
    )
        MorigamiMockManager(
            _initialOwner,
            _oToken,
            address(0),
            _feeCollector,
            _sellFeeNumerator
        )
    {
        wrappedNativeToken = _wrappedNativeToken;
    }

    function investWithWrappedNative(
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external view override returns (uint256 investmentAmount) {
        if (_paused.investmentsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.fromTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();
        if (quoteData.fromToken != address(0))
            revert CommonEventsAndErrors.InvalidToken(quoteData.fromToken);
        investmentAmount = quoteData.fromTokenAmount;
    }

    function exitToWrappedNative(
        IMorigamiInvestment.ExitQuoteData memory quoteData,
        address recipient
    ) external override returns (uint256 toTokenAmount, uint256 toBurnAmount) {
        if (_paused.exitsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.investmentTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();
        if (quoteData.toToken != address(0))
            revert CommonEventsAndErrors.InvalidToken(quoteData.toToken);

        (uint256 nonFees, uint256 fees) = quoteData
            .investmentTokenAmount
            .splitSubtractBps(sellFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        toTokenAmount = toBurnAmount = nonFees;

        if (fees != 0) {
            oToken.safeTransfer(feeCollector, fees);
        }

        if (nonFees != 0) {
            IERC20(wrappedNativeToken).safeTransfer(recipient, nonFees);
        }
    }
}
