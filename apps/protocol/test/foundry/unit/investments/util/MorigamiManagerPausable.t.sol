pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";

import {MorigamiManagerPausable} from "contracts/investments/util/MorigamiManagerPausable.sol";
import {MorigamiElevatedAccess} from "contracts/common/access/MorigamiElevatedAccess.sol";
import {IMorigamiManagerPausable} from "contracts/interfaces/investments/util/IMorigamiManagerPausable.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";

contract MockPausable is MorigamiManagerPausable {
    constructor(address _initialOwner) MorigamiElevatedAccess(_initialOwner) {}

    function getPaused() external view returns (Paused memory) {
        return _paused;
    }
}

contract MorigamiManagerPausableTest is MorigamiTest {
    MockPausable public pausable;

    event PauserSet(address indexed account, bool canPause);
    event PausedSet(IMorigamiManagerPausable.Paused paused);

    function setUp() public {
        pausable = new MockPausable(origamiMultisig);
    }

    function test_initialization() public {
        assertEq(pausable.owner(), origamiMultisig);
        IMorigamiManagerPausable.Paused memory paused = pausable.getPaused();
        assertEq(paused.investmentsPaused, false);
        assertEq(paused.exitsPaused, false);
        assertEq(pausable.isPauser(origamiMultisig), false);
    }

    function test_access_setPaused() public {
        vm.prank(origamiMultisig);
        vm.expectRevert(
            abi.encodeWithSelector(CommonEventsAndErrors.InvalidAccess.selector)
        );
        pausable.setPaused(IMorigamiManagerPausable.Paused(true, true));

        expectElevatedAccess();
        pausable.setPaused(IMorigamiManagerPausable.Paused(true, true));
    }

    function test_access_setPauser() public {
        expectElevatedAccess();
        pausable.setPauser(alice, true);
    }

    function test_setPaused() public {
        vm.startPrank(origamiMultisig);
        pausable.setPauser(origamiMultisig, true);

        IMorigamiManagerPausable.Paused memory value = IMorigamiManagerPausable
            .Paused(true, true);
        emit PausedSet(value);
        pausable.setPaused(value);

        IMorigamiManagerPausable.Paused memory valueAfter = pausable
            .getPaused();
        assertEq(valueAfter.investmentsPaused, true);
        assertEq(valueAfter.exitsPaused, true);
    }

    function test_setPauser() public {
        vm.startPrank(origamiMultisig);

        emit PauserSet(alice, true);
        pausable.setPauser(alice, true);
        assertEq(pausable.isPauser(alice), true);

        emit PauserSet(alice, false);
        pausable.setPauser(alice, false);
        assertEq(pausable.isPauser(alice), false);
    }
}
