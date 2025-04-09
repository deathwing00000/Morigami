pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/investments/util/IMorigamiManagerPausable.sol)

/**
 * @title A mixin to add pause/unpause for Morigami manager contracts
 */
interface IMorigamiManagerPausable {
    struct Paused {
        bool investmentsPaused;
        bool exitsPaused;
    }

    event PauserSet(address indexed account, bool canPause);
    event PausedSet(Paused paused);

    /// @notice A set of accounts which are allowed to pause deposits/withdrawals immediately
    /// under emergency
    function pausers(address) external view returns (bool);

    /// @notice Pause/unpause deposits or withdrawals
    /// @dev Can only be called by allowed pausers or governance.
    function setPaused(Paused memory updatedPaused) external;

    /// @notice Allow/Deny an account to pause/unpause deposits or withdrawals
    function setPauser(address account, bool canPause) external;

    /// @notice Check if given account can pause investments/exits
    function isPauser(address account) external view returns (bool canPause);
}
