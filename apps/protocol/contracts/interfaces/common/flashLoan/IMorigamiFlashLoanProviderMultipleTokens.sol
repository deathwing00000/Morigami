pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/flashLoan/IOrigamiFlashLoanProvider.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice An Origami abstraction over FlashLoan providers
 */
interface IMorigamiFlashLoanProviderMultipleTokens {
    /**
     * @notice Initiate a flashloan for a multiple tokens
     * The caller must implement the `IMorigamiFlashLoanReceiverMultipleTokens()` interface.
     * @param tokens The ERC20 tokens to borrow
     * @param amounts The amounts to borrow
     * @param params Client specific abi encoded params which are passed through from the msg.sender
     *               and into the `flashLoanCallback()` call
     */
    function flashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory params
    ) external;
}
