pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { IOrigamiInvestment } from "contracts/interfaces/investments/IOrigamiInvestment.sol";
import { IOrigamiOracle } from "contracts/interfaces/common/oracle/IOrigamiOracle.sol";
import { IOrigamiLovTokenFlashAndBorrowManager } from "contracts/interfaces/investments/lovToken/managers/IOrigamiLovTokenFlashAndBorrowManager.sol";

import { OrigamiTest } from "test/foundry/OrigamiTest.sol";
import { OrigamiMath } from "contracts/libraries/OrigamiMath.sol";
import { ExternalContracts, LovTokenContracts, Origami_lovToken_TestDeployer as Deployer } from "test/foundry/deploys/lov-wETH-wBTC-2xLong-spark/Origami_lovToken_TestDeployer.t.sol";
import { LovTokenHelpers } from "test/foundry/libraries/LovTokenHelpers.t.sol";

contract Origami_lov_wETH_wBTC_2xLong_IntegrationTestBase is OrigamiTest {
    using OrigamiMath for uint256;

    error BadSwapParam(uint256 expected, uint256 found);
    error UnknownSwapDownAmount(uint256 amount);
    error UnknownSwapUpAmount(uint256 amount);
    error InvalidRebalanceUpParam();
    error InvalidRebalanceDownParam();

    Deployer internal deployer;
    ExternalContracts public externalContracts;
    LovTokenContracts public lovTokenContracts;

    uint256 expectedSwapPrice = 0.04694340e8;

    /// @dev for dummy swapper, caller decides the rate :-)
    struct SwapData {
        uint256 buyTokenAmount;
    }

    function setUp() public virtual {
        fork("mainnet", 19865157);
        vm.warp(1715652372);

        deployer = new Deployer(); 
        origamiMultisig = address(deployer);
        (externalContracts, lovTokenContracts) = deployer.deployForked(origamiMultisig, feeCollector, overlord);
    }

    function investlovToken(address account, uint256 amount) internal returns (uint256 amountOut) {
        deal(address(externalContracts.reserveToken), account, amount, false);
        vm.startPrank(account);
        externalContracts.reserveToken.approve(address(lovTokenContracts.lovToken), amount);

        (IOrigamiInvestment.InvestQuoteData memory quoteData, ) = lovTokenContracts.lovToken.investQuote(
            amount,
            address(externalContracts.reserveToken),
            0,
            0
        );

        amountOut = lovTokenContracts.lovToken.investWithToken(quoteData);
    }

    function exitlovToken(address account, uint256 amount, address recipient) internal returns (uint256 amountOut) {
        vm.startPrank(account);

        (IOrigamiInvestment.ExitQuoteData memory quoteData, ) = lovTokenContracts.lovToken.exitQuote(
            amount,
            address(externalContracts.reserveToken),
            0,
            0
        );

        amountOut = lovTokenContracts.lovToken.exitToToken(quoteData, recipient);
    }

    function rebalanceDownParams(
        uint256 targetAL,
        uint256 swapSlippageBps,
        uint256 alSlippageBps
    ) internal virtual returns (
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams memory params,
        uint256 reservesAmount
    ) {
        reservesAmount = LovTokenHelpers.solveRebalanceDownAmount(lovTokenContracts.lovTokenManager, targetAL);

        // Use the oracle price (and scale for the debt token)
        // Round down to be conservative on how much is borrowed
        params.flashLoanAmount = lovTokenContracts.reserveToDebtOracle.convertAmount(
            address(externalContracts.reserveToken),
            reservesAmount,
            IOrigamiOracle.PriceType.SPOT_PRICE,
            OrigamiMath.Rounding.ROUND_DOWN
        );

        (reservesAmount, params.swapData) = swapRebalanceDownQuote(params.flashLoanAmount);

        // mint reserveToken - doMint not working for wETH
        deal(address(externalContracts.reserveToken), address(lovTokenContracts.swapper), reservesAmount);

        params.minNewAL = uint128(targetAL.subtractBps(alSlippageBps, OrigamiMath.Rounding.ROUND_DOWN));
        params.maxNewAL = uint128(targetAL.addBps(alSlippageBps, OrigamiMath.Rounding.ROUND_UP));
        params.minExpectedReserveToken = reservesAmount.subtractBps(swapSlippageBps, OrigamiMath.Rounding.ROUND_DOWN);
    }

    // Increase liabilities to lower A/L
    function doRebalanceDown(
        uint256 targetAL, 
        uint256 slippageBps, 
        uint256 alSlippageBps
    ) internal virtual returns (uint256 reservesAmount) {
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams memory params;
        (params, reservesAmount) = rebalanceDownParams(targetAL, slippageBps, alSlippageBps);

        vm.startPrank(origamiMultisig);
        lovTokenContracts.lovTokenManager.rebalanceDown(params);
    }
    
    function rebalanceUpParams(
        uint256 targetAL,
        uint256 swapSlippageBps,
        uint256 alSlippageBps
    ) internal virtual returns (
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams memory params
    ) {
        // ideal reserves amount to remove
        params.collateralToWithdraw = LovTokenHelpers.solveRebalanceUpAmount(lovTokenContracts.lovTokenManager, targetAL);

        (params.flashLoanAmount, params.swapData) = swapRebalanceUpQuote(params.collateralToWithdraw);

        // mint debtToken
        doMint(externalContracts.debtToken, address(lovTokenContracts.swapper), params.flashLoanAmount);

        // If there's a fee (currently disabled on Spark) then remove that from what we want to request
        uint256 feeBps = 0;
        params.flashLoanAmount = params.flashLoanAmount.inverseSubtractBps(feeBps, OrigamiMath.Rounding.ROUND_UP);

        // Apply slippage to the amount what's actually flashloaned is the lowest amount which
        // we would get when converting the collateral to the flashloan asset.
        // We need to be sure it can be paid off. Any remaining is repaid on the debt in Spark
        params.flashLoanAmount = params.flashLoanAmount.subtractBps(swapSlippageBps, OrigamiMath.Rounding.ROUND_DOWN);

        // When to sweep surplus balances and repay
        params.repaySurplusThreshold = 0;

        params.minNewAL = uint128(targetAL.subtractBps(alSlippageBps, OrigamiMath.Rounding.ROUND_DOWN));
        params.maxNewAL = uint128(targetAL.addBps(alSlippageBps, OrigamiMath.Rounding.ROUND_UP));
    }

    // Decrease liabilities to raise A/L
    function doRebalanceUp(
        uint256 targetAL, 
        uint256 slippageBps, 
        uint256 alSlippageBps
    ) internal virtual {
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams memory params = rebalanceUpParams(targetAL, slippageBps, alSlippageBps);
        vm.startPrank(origamiMultisig);

        lovTokenContracts.lovTokenManager.rebalanceUp(params);
    }

    function swapRebalanceDownQuote(uint256 debtAmount) internal pure returns (uint256 reserveAmount, bytes memory swapData) {
        // REQUEST:
        /*
        curl -X GET \
"https://api.1inch.dev/swap/v6.0/1/swap?src=0x6B175474E89094C44Da98b954EedeAC495271d0F&dst=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&amount=295707936477000000002947&from=0x0000000000000000000000000000000000000000&slippage=50&disableEstimate=true" \
-H "Authorization: Bearer PinnqIP4n9rxYRndzIyWDVrMfmGKUbZG" \
-H "accept: application/json" \
-H "content-type: application/json"
        */

        if (debtAmount == 147_353.968238500000000000e18) {
            reserveAmount = 49.923766577485884627e18;
            swapData = hex"07ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001f34131a9621d11f68000000000000000000000000000000000000000000000000015a6a6c98ee4856690000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000003f50000000000000000000000000000000000000003d70003a900037b00033100a0c9e75c480000000000000004040200000000000000000000000000000000000000000000030300028a00004f02a00000000000000000000000000000000000000000000000004548d6f4200e8ad1ee63c1e50160594a405d53811d3bc4766596efd80fd545a2706b175474e89094c44da98b954eedeac495271d0f00a007e5c0d20000000000000000000000000000000000000000000002170000ca0000b05120bebc44782c7db0a1a60cb6fe97d0b483032ff1c76b175474e89094c44da98b954eedeac495271d0f00443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006dcfd888f0020d6bdbf78dac17f958d2ee523a2206206994597c13d831ec700a0c9e75c480000000000000000211100000000000000000000000000000000000000000000000000011f0000d05100f5f5b97624542d72a9e06f04804bf81baa15e2b4dac17f958d2ee523a2206206994597c13d831ec70044394747c50000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002f20d7338a28e7ab000000000000000000000000000000000000000000000000000000000000000002a00000000000000000000000000000000000000000000000005b72191969cb40d7ee63c1e50011b815efb8f581194ae79006d24e0d814b7697f6dac17f958d2ee523a2206206994597c13d831ec700a007e5c0d200000000000000000000000000000000000000000000000000005500000600a03dd5cfd102a00000000000000000000000000000000000000000000000008a8ea557da45a315ee63c1e50188e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0f2fa6b66c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000002b4d4d931dc90acd300000000000000000006049d5815e2a980a06c4eca27c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a650020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a650000000000000000000000053a717a";
        } else if (debtAmount == 294_707.936477000000002947e18) {
            reserveAmount = 99.830085268028019440e18;
            swapData = hex"07ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e6826352c43a23edb83000000000000000000000000000000000000000000000002b4b5dad07ce229780000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000004930000000000000000000000000000000000000004750004470004190003cf00a0c9e75c48000000000000000404020000000000000000000000000000000000000000000003a10002df00004f02a00000000000000000000000000000000000000000000000008a894e74990a9342ee63c1e50160594a405d53811d3bc4766596efd80fd545a2706b175474e89094c44da98b954eedeac495271d0f00a007e5c0d200000000000000000000000000000000000000026c0000d00000b600000600a03dd5cfd15120bebc44782c7db0a1a60cb6fe97d0b483032ff1c7a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800443df021240000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000dba2459e10020d6bdbf78dac17f958d2ee523a2206206994597c13d831ec700a0c9e75c4800000000000000230c0300000000000000000000000000000000000000000000016e00011f00004f02a000000000000000000000000000000000000000000000000010a18e0b61122c08ee63c1e500c7bbec68d12a0d1830360f8ec58fa599ba1b0e9bdac17f958d2ee523a2206206994597c13d831ec75100f5f5b97624542d72a9e06f04804bf81baa15e2b4dac17f958d2ee523a2206206994597c13d831ec70044394747c500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042860cfade963767000000000000000000000000000000000000000000000000000000000000000002a0000000000000000000000000000000000000000000000000c1f6384a25f7d3edee63c1e50011b815efb8f581194ae79006d24e0d814b7697f6dac17f958d2ee523a2206206994597c13d831ec700a007e5c0d200000000000000000000000000000000000000000000000000009e00004f02a00000000000000000000000000000000000000000000000000000000db8ef61f4ee63c1e5015777d92f208679db4b9778590fa3cab3ac9e21686b175474e89094c44da98b954eedeac495271d0f02a0000000000000000000000000000000000000000000000001150eb90b7e375ed9ee63c1e50188e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0f2fa6b66c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000005696bb5a0f9c452f000000000000000000006049d5815e2a980a06c4eca27c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a650020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a6500000000000000000000000000053a717a";
        } else if (debtAmount == 295_707.936477000000002947e18) {
            reserveAmount = 100.352478445612773583e18;
            swapData = hex"07ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e9e5bfeda0980dedb83000000000000000000000000000000000000000000000002b855cfba606598670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000003740000000000000000000000000000000000000003560003280002fa0002b000a0c9e75c480000000000000006020200000000000000000000000000000000000000000000028200018c00013d00a007e5c0d20000000000000000000000000000000000000000000001190000ca0000b05120bebc44782c7db0a1a60cb6fe97d0b483032ff1c76b175474e89094c44da98b954eedeac495271d0f00443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006e2f3c0f30020d6bdbf78dac17f958d2ee523a2206206994597c13d831ec702a00000000000000000000000000000000000000000000000008b3e4295dd9de5f4ee63c1e50011b815efb8f581194ae79006d24e0d814b7697f6dac17f958d2ee523a2206206994597c13d831ec702a00000000000000000000000000000000000000000000000008b431efbd6c48064ee63c1e50160594a405d53811d3bc4766596efd80fd545a2706b175474e89094c44da98b954eedeac495271d0f00a007e5c0d20000000000000000000000000000000000000000000000000000d200000600a03dd5cfd100a0c9e75c480000000000000000300200000000000000000000000000000000000000000000000000009e00004f02a000000000000000000000000000000000000000000000000010b621162efd5cf2ee63c1e5011ac1a8feaaea1900c4166deeed0c11cc10669d36a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4802a0000000000000000000000000000000000000000000000001911e4d127d05d51cee63c1e50188e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0f2fa6b66c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000570ab9f74c0cb30cf00000000000000000006049d5815e2a980a06c4eca27c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a650020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2111111125421ca6dc452d289314280a0f8842a65000000000000000000000000053a717a";
        } else if (debtAmount == 4.69434e8) {
            reserveAmount = 99.998e18;
            swapData = abi.encode(SwapData(reserveAmount));
        } else if (debtAmount == 9.38868e8) {
            reserveAmount = 199.98e18;
            swapData = abi.encode(SwapData(reserveAmount));
        } else if (debtAmount == 9.42868e8) {
            reserveAmount = 200.832e18;
            swapData = abi.encode(SwapData(reserveAmount));
        } else {
            revert UnknownSwapDownAmount(debtAmount);
        }
    }

    function swapRebalanceUpQuote(uint256 reserveAmount) internal pure returns (uint256 debtAmount, bytes memory swapData) {
        // REQUEST:
        /*
        curl -X GET \
"https://api.1inch.dev/swap/v6.0/1/swap?src=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2&dst=0x6B175474E89094C44Da98b954EedeAC495271d0F&amount=4614757656831013976&from=0x0000000000000000000000000000000000000000&slippage=0.1&disableEstimate=true" \
-H "Authorization: Bearer PinnqIP4n9rxYRndzIyWDVrMfmGKUbZG" \
-H "accept: application/json" \
-H "content-type: application/json"
        */
        
        if (reserveAmount == 4.614757656831013976e18) {
            debtAmount = 13_587.794809988966529808e18;
            swapData = hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000400ae9a38bed34580000000000000000000000000000000000000000000002dfdbf6f112fe6a528e28000000000000000000000060594a405d53811d3bc4766596efd80fd545a270053a717a";
        } else if (reserveAmount == 100.352478445612773583e18) {
            debtAmount = 295_140.119043167657668878e18;
            swapData = hex"07ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000570ab9f74c0cb30cf000000000000000000000000000000000000000000003e6f940dbfd787b992490000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000004640000000000000000000000000000000000000004460004180003ea0003a000a0c9e75c480000000000000000080200000000000000000000000000000000000000000000000000037200015200a007e5c0d200000000000000000000000000000000000000000000000000012e0000f400a0c9e75c48000000000000000029090000000000000000000000000000000000000000000000000000c600006302a000000000000000000000000000000000000000000000000000000002732ac10cee63c1e5816ca298d2983ab03aa1da7679389d955a4efee15cc02aaa39b223fe8d0a0e5c4f27ead9083c756cc23058ef90929cb8180174d74c507176cca6835d7302a00000000000000000000000000000000000000000000000000000000b292148afee63c1e58111b815efb8f581194ae79006d24e0d814b7697f6c02aaa39b223fe8d0a0e5c4f27ead9083c756cc23058ef90929cb8180174d74c507176cca6835d7340203058ef90929cb8180174d74c507176cca6835d73dd93f59a000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900a007e5c0d20000000000000000000000000000000000000000000001fc0001f60001dc00a0c9e75c48000000000000001c14020000000000000000000000000000000000000000000001ae00009e00004f02a0000000000000000000000000000000000000000000000000000000022d85a4b1ee63c1e5001ac1a8feaaea1900c4166deeed0c11cc10669d36c02aaa39b223fe8d0a0e5c4f27ead9083c756cc202a000000000000000000000000000000000000000000000000000000015c42ec5e5ee63c1e50088e6a0c2ddd26feeb64f039a2c41296fcb3f5640c02aaa39b223fe8d0a0e5c4f27ead9083c756cc25120d17b3c9784510e33cd5b87b490e79253bcd81e2ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc2004458d30ac9000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e7b05bd560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd0900000000000000000000000000000000000000000000000000000000664973480020d6bdbf78a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800a0fd53121f00a0f2fa6b666b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000003e7f93f216646e3c310e000000000000000045442eb3cdf5f2b280a06c4eca276b175474e89094c44da98b954eedeac495271d0f111111125421ca6dc452d289314280a0f8842a650020d6bdbf786b175474e89094c44da98b954eedeac495271d0f111111125421ca6dc452d289314280a0f8842a6500000000000000000000000000000000000000000000000000000000053a717a";
        } else if (reserveAmount == 16.669999999999999999e18) {
            debtAmount = 0.78246823e8;
            swapData = abi.encode(SwapData(debtAmount));
        } else if (reserveAmount == 200.832e18) {
            debtAmount = 9.42773722e8;
            swapData = abi.encode(SwapData(debtAmount));
        } else {
            revert UnknownSwapUpAmount(reserveAmount);
        }
    }
}
