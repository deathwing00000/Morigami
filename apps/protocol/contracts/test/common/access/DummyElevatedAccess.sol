pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { MorigamiElevatedAccess } from "contracts/common/access/MorigamiElevatedAccess.sol";

/* solhint-disable func-name-mixedcase */
contract DummyElevatedAccess is MorigamiElevatedAccess {
    constructor(
        address _initialOwner
    ) MorigamiElevatedAccess(_initialOwner)
    // solhint-disable-next-line no-empty-blocks
    {}

    // solhint-disable-next-line no-empty-blocks
    function validateOnlyElevatedAccess() public view onlyElevatedAccess {}

    function checkSig() public view {
        validateOnlyElevatedAccess();
    }

    function checkSigThis() public view {
        this.validateOnlyElevatedAccess();
    }

    // A magic function with a signature of 0x00000000
    function wycpnbqcyf() external view onlyElevatedAccess {}
}

