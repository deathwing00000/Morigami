pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/flashLoan/IOrigamiFlashLoanReceiver.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice Handle Flash Loan callback's originated from a `IOrigamiFlashLoanProvider`
 */
interface IMorigamiFlashLoanReceiverMultipleTokens {
    /**
     * @notice Invoked from IMorigamiFlashLoanProviderMultipleTokens once a flash loan is successfully
     * received, to the msg.sender of `flashLoan()`
     * @dev Must return false (or revert) if handling within the callback failed.
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
    ) external returns (bool success);
}
