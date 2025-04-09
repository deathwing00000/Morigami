pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {MorigamiStableChainlinkOracle} from "contracts/common/oracle/MorigamiStableChainlinkOracle.sol";
import {MorigamiWstEthToEthOracle} from "contracts/common/oracle/MorigamiWstEthToEthOracle.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {MockStEthToken} from "contracts/test/external/lido/MockStEthToken.m.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {Range} from "contracts/libraries/Range.sol";

/* solhint-disable func-name-mixedcase, contract-name-camelcase, not-rely-on-time */
contract MorigamiWstEthToEthOracleTest is MorigamiTest {
    DummyOracle public clStEthToEthOracle;
    MorigamiStableChainlinkOracle public oStEthToEthOracle;
    MorigamiWstEthToEthOracle public oWstEthToEthOracle;
    MockStEthToken public stEthToken;

    uint96 public constant STETH_INTEREST_RATE = 0.04e18;
    uint256 public constant STETH_ETH_HISTORIC_RATE = 1e18;
    uint256 public constant STETH_ETH_ORACLE_RATE = 1.001640797743598e18;

    address public wstEthToken = makeAddr("wstEthToken");
    address public wEthToken = address(0);

    function setUp() public {
        vm.warp(1672531200); // 1 Jan 2023

        // 18 decimals
        clStEthToEthOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 1,
                answer: int256(STETH_ETH_ORACLE_RATE),
                startedAt: 0,
                updatedAtLag: 0,
                answeredInRound: 1
            }),
            18
        );

        stEthToken = new MockStEthToken(origamiMultisig, STETH_INTEREST_RATE);

        oStEthToEthOracle = new MorigamiStableChainlinkOracle(
            origamiMultisig,
            IMorigamiOracle.BaseOracleParams(
                "stETH/ETH",
                address(stEthToken),
                18,
                address(wEthToken),
                18
            ),
            STETH_ETH_HISTORIC_RATE,
            address(clStEthToEthOracle),
            100 days,
            Range.Data(0.99e18, 1.01e18),
            true,
            true
        );

        oWstEthToEthOracle = new MorigamiWstEthToEthOracle(
            IMorigamiOracle.BaseOracleParams(
                "wstETH/ETH",
                address(wstEthToken),
                18,
                address(wEthToken),
                18
            ),
            address(stEthToken),
            address(oStEthToEthOracle)
        );

        // Kick off the stETH accrual
        {
            vm.startPrank(overlord);
            deal(overlord, 10_000e18);
            stEthToken.submit{value: 10_000e18}(address(0));

            // Skip forward in time so wstETH:stETH increases
            skip(365 days);
        }
    }

    function test_latestPrice_spot_roundDown() public {
        uint256 ratio = stEthToken.getPooledEthByShares(1e18);
        uint256 expectedRate = 1.042518534162195584e18;
        assertEq(expectedRate, (ratio * STETH_ETH_ORACLE_RATE) / 1e18);

        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            expectedRate
        );
        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            expectedRate + 1
        );

        vm.warp(block.timestamp + 365 days);
        ratio = stEthToken.getPooledEthByShares(1e18);
        expectedRate = 1.085064522651268518e18;
        assertEq(expectedRate, (ratio * STETH_ETH_ORACLE_RATE) / 1e18);

        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            expectedRate
        );
        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            expectedRate + 1
        );
    }

    function test_latestPrice_historic() public {
        uint256 ratio = stEthToken.getPooledEthByShares(1e18);
        uint256 expectedRate = 1.040810774192388226e18;
        assertEq(expectedRate, (ratio * STETH_ETH_HISTORIC_RATE) / 1e18);

        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            expectedRate
        );
        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            expectedRate
        );

        vm.warp(block.timestamp + 365 days);
        ratio = stEthToken.getPooledEthByShares(1e18);
        expectedRate = 1.083287067674958553e18;
        assertEq(expectedRate, (ratio * STETH_ETH_HISTORIC_RATE) / 1e18);

        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            ),
            expectedRate
        );
        assertEq(
            oWstEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            expectedRate
        );
    }

    function test_latestPrices() public {
        (
            uint256 spot,
            uint256 hist,
            address baseAsset,
            address quoteAsset
        ) = oWstEthToEthOracle.latestPrices(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP,
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_DOWN
            );
        // Based off the wstETH/ETH price, so includes the wstETH/stETH ratio
        assertEq(spot, 1.042518534162195585e18);
        assertEq(hist, 1.040810774192388226e18);
        assertEq(baseAsset, address(wstEthToken));
        assertEq(quoteAsset, wEthToken);
    }
}
