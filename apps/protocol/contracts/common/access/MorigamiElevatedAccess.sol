pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/access/MorigamiElevatedAccessBase.sol)

import { MorigamiElevatedAccessBase } from "contracts/common/access/MorigamiElevatedAccessBase.sol";

/**
 * @notice Inherit to add Owner roles for DAO elevated access.
 */ 
abstract contract MorigamiElevatedAccess is MorigamiElevatedAccessBase {
    constructor(address initialOwner) {
        _init(initialOwner);
    }
}
