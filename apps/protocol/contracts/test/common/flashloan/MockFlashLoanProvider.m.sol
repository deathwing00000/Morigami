pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { IMorigamiFlashLoanProvider } from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProvider.sol";
import { IMorigamiFlashLoanReceiver } from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

contract MockFlashLoanProvider is IMorigamiFlashLoanProvider {
    using SafeERC20 for IERC20;

    uint256 public feeBps = 0;

    event FlashLoan(address indexed account, uint256 amount, uint256 fee);

    /**
     * @notice Initiate a flashloan for a single token
     * The caller must implement the `IMorigamiFlashLoanReceiver()` interface
     * and must repay the loaned tokens to this contract within that function call. 
     * The loaned amount is always repaid to Aave/Spark within the same transaction.
     * @dev Upon FL success, Aave/Spark will call the `executeOperation()` callback
     */
    function flashLoan(IERC20 token, uint256 amount, bytes memory params) external override {
        uint256 _balanceBefore = token.balanceOf(address(this));
        if (_balanceBefore < amount) {
            revert CommonEventsAndErrors.InsufficientBalance(
                address(token), 
                amount, 
                _balanceBefore
            );
        }

        uint256 _feeAmt = MorigamiMath.mulDiv(
            amount, 
            feeBps, 
            MorigamiMath.BASIS_POINTS_DIVISOR, 
            MorigamiMath.Rounding.ROUND_UP
        );

        emit FlashLoan(msg.sender, amount, _feeAmt);
        token.safeTransfer(msg.sender, amount);
        if (!IMorigamiFlashLoanReceiver(msg.sender).flashLoanCallback(token, amount, _feeAmt, params)) {
            revert CommonEventsAndErrors.InvalidParam();
        }

        if (token.balanceOf(address(this)) != _balanceBefore) {
            revert CommonEventsAndErrors.InsufficientBalance(
                address(token), 
                _balanceBefore, 
                token.balanceOf(address(this))
            );
        }
    }

    function setFeeBps(uint256 _feeBps) external {
        if (_feeBps > MorigamiMath.BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();
        feeBps = _feeBps;
    }
}
