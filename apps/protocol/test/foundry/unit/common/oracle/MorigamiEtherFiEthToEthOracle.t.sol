pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEtherFiLiquidityPool} from "contracts/interfaces/external/etherfi/IEtherFiLiquidityPool.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {MorigamiEtherFiEthToEthOracle} from "contracts/common/oracle/MorigamiEtherFiEthToEthOracle.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";

contract MockEtherFiLiquidityPool is IEtherFiLiquidityPool {
    function amountForShare(uint256) external pure returns (uint256) {
        return 1.036311707261417860e18;
    }
}

/* solhint-disable func-name-mixedcase, contract-name-camelcase, not-rely-on-time */
contract MorigamiEtherFiEthToEthOracleTestBase is MorigamiTest {
    MorigamiEtherFiEthToEthOracle public oWeEthToEthOracle;

    IERC20 internal weEthToken;
    MockEtherFiLiquidityPool internal etherfiLiquidityPool;
    IAggregatorV3Interface internal redstoneWeEthToEthOracle;

    uint128 public constant stalenessThreshold = 24 hours + 15 minutes;
    uint256 public constant validPriceDiffBps = 100; // 1%

    function setUp() public {
        vm.warp(1713314062);

        weEthToken = new DummyMintableToken(
            origamiMultisig,
            "weETH",
            "weETH",
            18
        );
        etherfiLiquidityPool = new MockEtherFiLiquidityPool();

        redstoneWeEthToEthOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 0,
                answer: 1.03457952e8,
                startedAt: 1713264887,
                updatedAtLag: 0,
                answeredInRound: 0
            }),
            8
        );

        oWeEthToEthOracle = new MorigamiEtherFiEthToEthOracle(
            origamiMultisig,
            IMorigamiOracle.BaseOracleParams(
                "weETH/ETH",
                address(weEthToken),
                18,
                address(0),
                18
            ),
            address(redstoneWeEthToEthOracle),
            stalenessThreshold,
            validPriceDiffBps,
            address(etherfiLiquidityPool)
        );
    }
}

contract MorigamiEtherFiEthToEthOracleTestAdmin is
    MorigamiEtherFiEthToEthOracleTestBase
{
    event MaxRelativeToleranceBpsSet(uint256 bps);

    function test_initialization() public {
        assertEq(
            address(oWeEthToEthOracle.spotPriceOracle()),
            address(redstoneWeEthToEthOracle)
        );
        assertEq(
            oWeEthToEthOracle.spotPriceStalenessThreshold(),
            stalenessThreshold
        );
        assertEq(oWeEthToEthOracle.spotPricePrecisionScalar(), 1e10);
        assertEq(oWeEthToEthOracle.spotPricePrecisionScaleDown(), false);
        assertEq(
            oWeEthToEthOracle.maxRelativeToleranceBps(),
            validPriceDiffBps
        );
        assertEq(
            address(oWeEthToEthOracle.etherfiLiquidityPool()),
            address(etherfiLiquidityPool)
        );
    }

    function test_setMaxRelativeToleranceBps_failTooMuch() public {
        vm.prank(origamiMultisig);
        vm.expectRevert(
            abi.encodeWithSelector(CommonEventsAndErrors.InvalidParam.selector)
        );
        oWeEthToEthOracle.setMaxRelativeToleranceBps(10_001);
    }

    function test_setMaxRelativeToleranceBps_success() public {
        vm.startPrank(origamiMultisig);
        vm.expectEmit(address(oWeEthToEthOracle));
        emit MaxRelativeToleranceBpsSet(999);
        oWeEthToEthOracle.setMaxRelativeToleranceBps(999);
        assertEq(oWeEthToEthOracle.maxRelativeToleranceBps(), 999);
    }
}

contract MorigamiEtherFiEthToEthOracleTestAccess is
    MorigamiEtherFiEthToEthOracleTestBase
{
    function test_setMaxRelativeToleranceBps_access() public {
        expectElevatedAccess();
        oWeEthToEthOracle.setMaxRelativeToleranceBps(999);
    }
}

contract MorigamiEtherFiEthToEthOracleTestPrice is
    MorigamiEtherFiEthToEthOracleTestBase
{
    function test_latestPrice_spot_underThreshold() public {
        assertEq(
            oWeEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1.03457952e18
        );
    }

    function test_latestPrice_spot_overThreshold_premium() public {
        uint256 expectedRefPrice = 1.036311707261417860e18;
        uint256 oraclePrice = (expectedRefPrice * 1.01e18) / 1e18;
        vm.mockCall(
            address(redstoneWeEthToEthOracle),
            abi.encodeWithSelector(DummyOracle.latestRoundData.selector),
            abi.encode(
                0,
                oraclePrice / 1e10 + 1,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IMorigamiOracle.AboveMaxValidRange.selector,
                address(redstoneWeEthToEthOracle),
                1.04667483e18,
                expectedRefPrice
            )
        );
        oWeEthToEthOracle.latestPrice(
            IMorigamiOracle.PriceType.SPOT_PRICE,
            MorigamiMath.Rounding.ROUND_UP
        );
    }

    function test_latestPrice_spot_atThreshold_premium() public {
        uint256 expectedRefPrice = 1.036311707261417860e18;
        uint256 oraclePrice = (expectedRefPrice * 1.01e18) / 1e18;
        vm.mockCall(
            address(redstoneWeEthToEthOracle),
            abi.encodeWithSelector(DummyOracle.latestRoundData.selector),
            abi.encode(
                0,
                oraclePrice / 1e10,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        assertEq(
            oWeEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1.04667482e18
        );
    }

    function test_latestPrice_spot_overThreshold_discount() public {
        uint256 expectedRefPrice = 1.036311707261417860e18;
        uint256 oraclePrice = (expectedRefPrice * 0.99e18) / 1e18;
        vm.mockCall(
            address(redstoneWeEthToEthOracle),
            abi.encodeWithSelector(DummyOracle.latestRoundData.selector),
            abi.encode(
                0,
                oraclePrice / 1e10,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IMorigamiOracle.AboveMaxValidRange.selector,
                address(redstoneWeEthToEthOracle),
                1.02594859e18,
                expectedRefPrice
            )
        );
        oWeEthToEthOracle.latestPrice(
            IMorigamiOracle.PriceType.SPOT_PRICE,
            MorigamiMath.Rounding.ROUND_UP
        );
    }

    function test_latestPrice_spot_atThreshold_discount() public {
        uint256 expectedRefPrice = 1.036311707261417860e18;
        uint256 oraclePrice = (expectedRefPrice * 0.99e18) / 1e18;
        vm.mockCall(
            address(redstoneWeEthToEthOracle),
            abi.encodeWithSelector(DummyOracle.latestRoundData.selector),
            abi.encode(
                0,
                oraclePrice / 1e10 + 1,
                block.timestamp,
                block.timestamp,
                0
            )
        );
        assertEq(
            oWeEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.SPOT_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1.0259486e18
        );
    }

    function test_latestPrice_historic_underThreshold() public {
        assertEq(
            oWeEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1.036311707261417860e18
        );
    }

    function test_latestPrice_historic_overThreshold() public {
        // No error on historic if over threshold
        vm.mockCall(
            address(redstoneWeEthToEthOracle),
            abi.encodeWithSelector(DummyOracle.latestRoundData.selector),
            abi.encode(0, 1.047e8, block.timestamp, block.timestamp, 0)
        );
        assertEq(
            oWeEthToEthOracle.latestPrice(
                IMorigamiOracle.PriceType.HISTORIC_PRICE,
                MorigamiMath.Rounding.ROUND_UP
            ),
            1.036311707261417860e18
        );
    }
}
