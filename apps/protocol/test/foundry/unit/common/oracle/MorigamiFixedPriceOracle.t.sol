pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {MorigamiFixedPriceOracle} from "contracts/common/oracle/MorigamiFixedPriceOracle.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";

contract MockOracle is MorigamiOracleBase {
    constructor(
        BaseOracleParams memory baseParams
    ) MorigamiOracleBase(baseParams) {}

    function latestPrice(
        PriceType /*priceType*/,
        MorigamiMath.Rounding /*roundingMode*/
    ) public pure override returns (uint256 price) {
        return 1.0e18;
    }
}

/* solhint-disable func-name-mixedcase, contract-name-camelcase, not-rely-on-time */
contract MorigamiFixedPriceOracleTestBase is MorigamiTest {
    MorigamiFixedPriceOracle public oOracleFixed;
    MorigamiFixedPriceOracle public oOracleFixedNoCheck;

    MockOracle public oOracleCheck;

    address public token1 = makeAddr("token1");
    address public token2 = makeAddr("token2");

    function setUp() public {
        vm.warp(1672531200); // 1 Jan 2023

        oOracleCheck = new MockOracle(
            IMorigamiOracle.BaseOracleParams(
                "token1/token2",
                token1,
                18,
                token2,
                18
            )
        );

        oOracleFixed = new MorigamiFixedPriceOracle(
            IMorigamiOracle.BaseOracleParams(
                "token1/token2",
                token1,
                18,
                token2,
                18
            ),
            0.9999e18,
            address(oOracleCheck)
        );

        oOracleFixedNoCheck = new MorigamiFixedPriceOracle(
            IMorigamiOracle.BaseOracleParams(
                "token1/token2",
                token1,
                18,
                token2,
                18
            ),
            1.1e18,
            address(0)
        );
    }
}

contract MorigamiFixedPriceOracleTestInit is MorigamiFixedPriceOracleTestBase {
    function test_initialization_fixed() public {
        assertEq(oOracleFixed.decimals(), 18);
        assertEq(oOracleFixed.precision(), 1e18);
        assertEq(oOracleFixed.description(), "token1/token2");
        assertEq(oOracleFixed.assetScalingFactor(), 1e18);
        assertEq(oOracleFixed.baseAsset(), token1);
        assertEq(oOracleFixed.quoteAsset(), token2);

        assertEq(
            address(oOracleFixed.priceCheckOracle()),
            address(oOracleCheck)
        );
    }

    function test_initialization_noCheck() public {
        assertEq(oOracleFixedNoCheck.decimals(), 18);
        assertEq(oOracleFixedNoCheck.precision(), 1e18);
        assertEq(oOracleFixedNoCheck.description(), "token1/token2");
        assertEq(oOracleFixedNoCheck.assetScalingFactor(), 1e18);
        assertEq(oOracleFixedNoCheck.baseAsset(), token1);
        assertEq(oOracleFixedNoCheck.quoteAsset(), token2);

        assertEq(address(oOracleFixedNoCheck.priceCheckOracle()), address(0));
    }
}

contract MorigamiFixedPriceOracleWithCheck_LatestPrice is
    MorigamiFixedPriceOracleTestBase
{
    function test_latestPrice_success() public {
        assertEq(
            oOracleFixed.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            0.9999e18
        );
        assertEq(
            oOracleFixed.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            0.9999e18
        );

        assertEq(
            oOracleFixed.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            0.9999e18
        );
        assertEq(
            oOracleFixed.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            0.9999e18
        );
    }

    function test_latestPrice_fail_check() public {
        vm.mockCallRevert(
            address(oOracleCheck),
            abi.encodeWithSelector(MockOracle.latestPrice.selector),
            "bad price"
        );

        vm.expectRevert("bad price");
        oOracleFixed.latestPrice(
            IMorigamiOracle.PriceType.SPOT_PRICE,
            MorigamiMath.Rounding.ROUND_UP
        );
    }
}
