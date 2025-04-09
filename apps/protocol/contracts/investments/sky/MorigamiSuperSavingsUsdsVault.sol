pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/sky/MorigamiSuperSavingsUsdsVault.sol)

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IMorigamiDelegated4626Vault } from "contracts/interfaces/investments/erc4626/IMorigamiDelegated4626Vault.sol";
import { IMorigamiSuperSavingsUsdsManager } from "contracts/interfaces/investments/sky/IMorigamiSuperSavingsUsdsManager.sol";
import { ITokenPrices } from "contracts/interfaces/common/ITokenPrices.sol";
import { IMorigamiErc4626 } from "contracts/interfaces/common/IMorigamiErc4626.sol";
import { MorigamiErc4626 } from "contracts/common/MorigamiErc4626.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @title Morigami sUSDS+s ERC-4626 Vault
 * @notice The logic to farm the sUSDS is delegated to a manager.
 */
contract MorigamiSuperSavingsUsdsVault is
    MorigamiErc4626,
    IMorigamiDelegated4626Vault
{
    using SafeERC20 for IERC20;

    /// @inheritdoc IMorigamiDelegated4626Vault
    ITokenPrices public override tokenPrices;

    /// @dev The manager which handles the farming of USDS
    IMorigamiSuperSavingsUsdsManager private _manager;

    constructor(
        address initialOwner_,
        string memory name_,
        string memory symbol_,
        IERC20 asset_,
        address tokenPrices_
    ) 
        MorigamiErc4626(initialOwner_, name_, symbol_, asset_)
    {
        tokenPrices = ITokenPrices(tokenPrices_);
    }

    /// @inheritdoc IMorigamiDelegated4626Vault
    function setManager(address newManager) external override onlyElevatedAccess {
        if (newManager == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit ManagerSet(newManager);
        _manager = IMorigamiSuperSavingsUsdsManager(newManager);
    }

    /// @inheritdoc IMorigamiDelegated4626Vault
    function setTokenPrices(address _tokenPrices) external override onlyElevatedAccess {
        if (_tokenPrices == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit TokenPricesSet(_tokenPrices);
        tokenPrices = ITokenPrices(_tokenPrices);
    }

    /**
     * @notice Emit an event from the vault when the performance fees are updated
     */
    function logPerformanceFeesSet(uint256 performanceFees) external {
        if (msg.sender != address(_manager)) revert CommonEventsAndErrors.InvalidAccess();
        emit PerformanceFeeSet(performanceFees);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view override(IERC4626, MorigamiErc4626) returns (uint256) {
        return _manager.totalAssets();
    }

    /// @inheritdoc IMorigamiErc4626
    function areDepositsPaused() external virtual override(IMorigamiErc4626, MorigamiErc4626) view returns (bool) {
        return _manager.areDepositsPaused();
    }

    /// @inheritdoc IMorigamiErc4626
    function areWithdrawalsPaused() external virtual override(IMorigamiErc4626, MorigamiErc4626) view returns (bool) {
        return _manager.areWithdrawalsPaused();
    }

    /// @inheritdoc IMorigamiDelegated4626Vault
    function manager() external override view returns (address) {
        return address(_manager);
    }

    /// @inheritdoc IMorigamiDelegated4626Vault
    function performanceFeeBps() external override view returns (uint48) {
        // Return the total fee for both the caller (to pay for gas) and Morigami
        (uint48 callerFeeBps, uint48 origamiFeeBps) = _manager.performanceFeeBps();
        return callerFeeBps + origamiFeeBps; 
    }

    /// @dev Pull freshly deposited sUSDS and deposit into the manager
    function _depositHook(address caller, uint256 assets) internal override {
        SafeERC20.safeTransferFrom(_asset, caller, address(_manager), assets);
        _manager.deposit(type(uint256).max);
    }

    /// @dev Pull sUSDS from the manager which also sends to the receiver
    function _withdrawHook(
        uint256 assets,
        address receiver
    ) internal override {
        _manager.withdraw(assets, receiver);
    }
}
