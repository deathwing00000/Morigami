pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/util/MorigamiManagerPausable.sol)

import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";
import { MorigamiElevatedAccess } from "contracts/common/access/MorigamiElevatedAccess.sol";
import { IMorigamiManagerPausable } from "contracts/interfaces/investments/util/IMorigamiManagerPausable.sol";

/**
 * @title A mixin to add pause/unpause for Morigami manager contracts
 */
abstract contract MorigamiManagerPausable is IMorigamiManagerPausable, MorigamiElevatedAccess {
    /**
     * @notice A set of accounts which are allowed to pause deposits/withdrawals immediately
     * under emergency
     */
    mapping(address account => bool canPause) public pausers;

    /**
     * @notice The current paused/unpaused state of deposits/exits.
     */
    Paused internal _paused;

    /**
     * @notice Pause/unpause deposits or exits
     * @dev Can only be called by allowed pausers.
     */
    function setPaused(Paused calldata updatedPaused) external {
        if (!pausers[msg.sender]) revert CommonEventsAndErrors.InvalidAccess();
        emit PausedSet(updatedPaused);
        _paused = updatedPaused;
    }

    /**
     * @notice Allow/Deny an account to pause/unpause deposits or exits
     */
    function setPauser(address account, bool canPause) external onlyElevatedAccess {
        pausers[account] = canPause;
        emit PauserSet(account, canPause);
    }

    /**
     * @notice Check if given account can pause deposits/exits
     */
    function isPauser(address account) external view override returns (bool canPause) {
        canPause = pausers[account];
    }
}
