pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {PRBMath_MulDiv_Overflow} from "@prb/math/src/Common.sol";

contract MorigamiMathTest is MorigamiTest {
    using MorigamiMath for uint256;

    function test_scaleUp() public {
        assertEq(MorigamiMath.scaleUp(123.123450e6, 1e12), 123.123450e18);
        assertEq(MorigamiMath.scaleUp(123.123454e6, 1e12), 123.123454e18);
        assertEq(MorigamiMath.scaleUp(123.123455e6, 1e12), 123.123455e18);
        assertEq(MorigamiMath.scaleUp(123.123456e6, 1e12), 123.123456e18);

        assertEq(MorigamiMath.scaleUp(123.1234560e18, 1), 123.1234560e18);
        assertEq(MorigamiMath.scaleUp(123.1234564e18, 1), 123.1234564e18);
        assertEq(MorigamiMath.scaleUp(123.1234565e18, 1), 123.1234565e18);
        assertEq(MorigamiMath.scaleUp(123.1234566e18, 1), 123.1234566e18);
    }
    function test_scaleDown() public {
        assertEq(uint256(10) ** (18 - 18), 1);

        assertEq(
            MorigamiMath.scaleDown(
                123.1234560e18,
                1e12,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.123456e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234564e18,
                1e12,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.123456e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234565e18,
                1e12,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.123456e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234566e18,
                1e12,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.123456e6
        );

        assertEq(
            MorigamiMath.scaleDown(
                123.1234560e18,
                1e12,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.123456e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234564e18,
                1e12,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.123457e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234565e18,
                1e12,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.123457e6
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234566e18,
                1e12,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.123457e6
        );

        assertEq(
            MorigamiMath.scaleDown(
                123.1234560e18,
                1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.1234560e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234564e18,
                1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.1234564e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234565e18,
                1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.1234565e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234566e18,
                1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            123.1234566e18
        );

        assertEq(
            MorigamiMath.scaleDown(
                123.1234560e18,
                1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.1234560e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234564e18,
                1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.1234564e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234565e18,
                1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.1234565e18
        );
        assertEq(
            MorigamiMath.scaleDown(
                123.1234566e18,
                1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            123.1234566e18
        );

        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            type(uint256).max
        );
    }

    function test_scaleDown_max() public {
        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            type(uint256).max
        );
        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                type(uint256).max,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            1
        );
        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                type(uint256).max,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1
        );
        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                type(uint256).max - 1,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            1
        );
        assertEq(
            MorigamiMath.scaleDown(
                type(uint256).max,
                type(uint256).max - 1,
                MorigamiMath.Rounding.ROUND_UP
            ),
            2
        );
    }

    function test_mulDiv() public {
        assertEq(
            MorigamiMath.mulDiv(
                123.456789123456789e18,
                3.123e18,
                4.4567e18,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            86.511443990521137174e18
        );
        assertEq(
            MorigamiMath.mulDiv(
                123.456789123456789e18,
                3.123e18,
                4.4567e18,
                MorigamiMath.Rounding.ROUND_UP
            ),
            86.511443990521137175e18
        );
    }

    function test_muldiv_max() public {
        assertEq(
            MorigamiMath.mulDiv(
                type(uint256).max,
                type(uint256).max,
                type(uint256).max,
                MorigamiMath.Rounding.ROUND_UP
            ),
            type(uint256).max
        );
        assertEq(
            MorigamiMath.mulDiv(
                type(uint256).max,
                type(uint256).max - 1,
                type(uint256).max,
                MorigamiMath.Rounding.ROUND_UP
            ),
            type(uint256).max - 1
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                PRBMath_MulDiv_Overflow.selector,
                type(uint256).max - 1,
                type(uint256).max - 1,
                type(uint256).max - 2
            )
        );
        MorigamiMath.mulDiv(
            type(uint256).max - 1,
            type(uint256).max - 1,
            type(uint256).max - 2,
            MorigamiMath.Rounding.ROUND_UP
        );
        // Warning - execution of test will stop here, it's unreachable when the error is thrown via an internal library.
    }

    function test_addBps_roundup() public {
        // 0%
        assertEq(
            MorigamiMath.addBps(100.123e3, 0, MorigamiMath.Rounding.ROUND_UP),
            100.123e3
        );

        // 10%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                1_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            110.136e3
        );

        // 33.333%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                3_333,
                MorigamiMath.Rounding.ROUND_UP
            ),
            133.494e3
        );

        // 100%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                10_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            200.246e3
        );

        // 110%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                11_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            210.259e3
        );
    }

    function test_addBps_rounddown() public {
        // 0%
        assertEq(
            MorigamiMath.addBps(100.123e3, 0, MorigamiMath.Rounding.ROUND_DOWN),
            100.123e3
        );

        // 10%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                1_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            110.135e3
        );

        // 33.333%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                3_333,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            133.493e3
        );

        // 100%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                10_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            200.246e3
        );

        // 110%
        assertEq(
            MorigamiMath.addBps(
                100.123e3,
                11_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            210.258e3
        );
    }

    function test_subtractBps_roundup() public {
        // 0%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                0,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            100.123e3
        );

        // 10%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                1_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            90.110e3
        );

        // 33.333%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                3_333,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            66.752e3
        );

        // 100%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                10_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            0
        );

        // 110%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                11_000,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            0
        );
    }

    function test_subtractBps_rounddown() public {
        // 0%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                0,
                MorigamiMath.Rounding.ROUND_UP
            ),
            100.123e3
        );

        // 10%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                1_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            90.111e3
        );

        // 33.333%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                3_333,
                MorigamiMath.Rounding.ROUND_UP
            ),
            66.753e3
        );

        // 100%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                10_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            0
        );

        // 110%
        assertEq(
            MorigamiMath.subtractBps(
                100.123e3,
                11_000,
                MorigamiMath.Rounding.ROUND_UP
            ),
            0
        );
    }

    function test_splitSubtractBps_roundup() public {
        uint256 rate = 3_330; // 33.3%

        uint256 amount = 600;
        (uint256 result, uint256 removed) = amount.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_UP
        );
        assertEq(result, 401);
        assertEq(removed, 199);

        amount = 601;
        (result, removed) = amount.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_UP
        );
        assertEq(result, 401);
        assertEq(removed, 200);
    }

    function test_splitSubtractBps_rounddown() public {
        uint256 rate = 3_330; // 33.3%

        uint256 amount = 600;
        (uint256 result, uint256 removed) = amount.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_DOWN
        );
        assertEq(result, 400);
        assertEq(removed, 200);

        amount = 601;
        (result, removed) = amount.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_DOWN
        );
        assertEq(result, 400);
        assertEq(removed, 201);
    }

    function test_inverseSubtractBps_fail() public {
        uint256 amount = 600;
        vm.expectRevert(
            abi.encodeWithSelector(CommonEventsAndErrors.InvalidParam.selector)
        );
        amount.inverseSubtractBps(10_000 + 1, MorigamiMath.Rounding.ROUND_UP);
    }

    function test_inverseSubtractBps_roundup() public {
        uint256 rate = 3_330; // 33.3%

        uint256 amount = 400;
        uint256 result = amount.inverseSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_UP
        );
        assertEq(result, 600);

        // And back the other way
        (uint256 result2, uint256 removed) = result.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_DOWN
        );
        assertEq(result2, amount);
        assertEq(removed, 200);

        assertEq(
            amount.inverseSubtractBps(0, MorigamiMath.Rounding.ROUND_UP),
            amount
        );
    }

    function test_inverseSubtractBps_rounddown() public {
        uint256 rate = 3_330; // 33.3%

        uint256 amount = 400;
        uint256 result = amount.inverseSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_DOWN
        );
        assertEq(result, 599);

        // And back the other way
        (uint256 result2, uint256 removed) = result.splitSubtractBps(
            rate,
            MorigamiMath.Rounding.ROUND_UP
        );
        assertEq(result2, amount);
        assertEq(removed, 199);

        assertEq(
            amount.inverseSubtractBps(0, MorigamiMath.Rounding.ROUND_DOWN),
            amount
        );
    }

    function test_relativeDifferenceBps_zeroRefValue() public {
        vm.expectRevert(
            abi.encodeWithSelector(CommonEventsAndErrors.InvalidParam.selector)
        );
        MorigamiMath.relativeDifferenceBps(
            100,
            0,
            MorigamiMath.Rounding.ROUND_DOWN
        );
    }

    function test_relativeDifferenceBps_lt_RefValue() public {
        assertEq(
            MorigamiMath.relativeDifferenceBps(
                100e18,
                110e18,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            909
        );

        assertEq(
            MorigamiMath.relativeDifferenceBps(
                100e18,
                110e18,
                MorigamiMath.Rounding.ROUND_UP
            ),
            910
        );
    }

    function test_relativeDifferenceBps_gt_RefValue() public {
        assertEq(
            MorigamiMath.relativeDifferenceBps(
                120e18,
                110e18,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            909
        );

        assertEq(
            MorigamiMath.relativeDifferenceBps(
                120e18,
                110e18,
                MorigamiMath.Rounding.ROUND_UP
            ),
            910
        );
    }

    function test_relativeDifferenceBps_eq_RefValue() public {
        assertEq(
            MorigamiMath.relativeDifferenceBps(
                110e18,
                110e18,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            0
        );
    }
}
