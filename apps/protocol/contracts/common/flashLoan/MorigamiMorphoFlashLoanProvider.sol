pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/flashLoan/MorigamiMorphoFlashLoanProvider.sol)

import { IMorpho } from "@morpho-org/morpho-blue/src/interfaces/IMorpho.sol";
import { IMorphoFlashLoanCallback } from "@morpho-org/morpho-blue/src/interfaces/IMorphoCallbacks.sol";

import { IMorigamiFlashLoanProvider } from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProvider.sol";
import { IMorigamiFlashLoanReceiver } from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @title MorigamiMorphoFlashLoanProvider
 * @notice A permisionless flashloan wrapper over Morpho
 * @dev The caller needs to implement the IMorigamiFlashLoanReceiver interface to receive the callback
 */ 
contract MorigamiMorphoFlashLoanProvider is IMorigamiFlashLoanProvider, IMorphoFlashLoanCallback {
    using SafeERC20 for IERC20;
    
    error CallbackFailure();

    /**
     * @notice The morpho singleton contract
     */
    IMorpho public immutable morpho;

    constructor(address _morphoAddress) {
        morpho = IMorpho(_morphoAddress);   
    }

    /**
     * @notice Initiate a flashloan for a single token
     * The caller must implement the `IMorigamiFlashLoanReceiver()` interface
     * and must repay the loaned tokens to this contract within that function call. 
     * The loaned amount is always repaid to Morpho within the same transaction.
     * @dev Upon FL success, Morpho will call the `onMorphoFlashLoan()` callback
     */
    function flashLoan(IERC20 token, uint256 amount, bytes calldata params) external override {
        // Encode:
        //  The msg.sender, which also doubles as the IMorigamiFlashLoanReceiver.
        //  The asset token.
        bytes memory _params = abi.encode(msg.sender, address(token), params);

        morpho.flashLoan(address(token), amount, _params);
    }

    /**
    * @notice Callback from Morpho after receiving the flash-borrowed assets
    * @dev After validation, flashLoanCallback() is called on the caller of flashLoan().
    * @param amount The amount of the flash-borrowed assets
    * @param params The byte-encoded params passed when initiating the flashloan
    */
    function onMorphoFlashLoan(uint256 amount, bytes calldata params) external {
        // Can only be called by the Morpho pool, and the FL can only ever be initiated by this contract.
        if (msg.sender != address(morpho)) revert CommonEventsAndErrors.InvalidAccess();

        (IMorigamiFlashLoanReceiver flReceiver, IERC20 token, bytes memory _params) = abi.decode(
            params, (IMorigamiFlashLoanReceiver, IERC20, bytes)
        );

        // Transfer the asset to the Morigami FL receiver, and approve the repayment to Morpho in full
        token.safeTransfer(address(flReceiver), amount);
        token.forceApprove(address(morpho), amount);

        // Finally have the receiver handle the callback
        bool success = flReceiver.flashLoanCallback(token, amount, 0, _params);
        if (!success) revert CallbackFailure();
    }
}
