pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiErc4626} from "contracts/common/MorigamiErc4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockErc4626VaultWithFees is MorigamiErc4626 {
    uint256 private _depositFeeBps;
    uint256 private _exitFeeBps;

    constructor(
        address initialOwner_,
        string memory name_,
        string memory symbol_,
        IERC20 asset_,
        uint256 depositFeeBps_,
        uint256 exitFeeBps_
    ) MorigamiErc4626(initialOwner_, name_, symbol_, asset_) {
        _depositFeeBps = depositFeeBps_;
        _exitFeeBps = exitFeeBps_;
    }

    function depositFeeBps() public view override returns (uint256) {
        return _depositFeeBps;
    }

    function withdrawalFeeBps() public view override returns (uint256) {
        return _exitFeeBps;
    }
}
