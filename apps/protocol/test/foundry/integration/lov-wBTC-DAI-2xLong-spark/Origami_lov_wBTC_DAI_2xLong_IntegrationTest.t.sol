pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { stdError } from "forge-std/StdError.sol";

import { Origami_lov_wBTC_DAI_2xLong_IntegrationTestBase } from "test/foundry/integration/lov-wBTC-DAI-2xLong-spark/Origami_lov_wBTC_DAI_2xLong_IntegrationTestBase.t.sol";
import { Origami_lovToken_TestConstants as Constants } from "test/foundry/deploys/lov-wBTC-DAI-2xLong-spark/Origami_lovToken_TestConstants.t.sol";
import { IOrigamiOracle } from "contracts/interfaces/common/oracle/IOrigamiOracle.sol";
import { IOrigamiInvestment } from "contracts/interfaces/investments/IOrigamiInvestment.sol";
import { IOrigamiLovTokenManager } from "contracts/interfaces/investments/lovToken/managers/IOrigamiLovTokenManager.sol";
import { IOrigamiLovTokenFlashAndBorrowManager } from "contracts/interfaces/investments/lovToken/managers/IOrigamiLovTokenFlashAndBorrowManager.sol";

import { OrigamiMath } from "contracts/libraries/OrigamiMath.sol";
import { Errors as AaveErrors } from "@aave/core-v3/contracts/protocol/libraries/helpers/Errors.sol";

contract Origami_lov_wBTC_DAI_2xLong_IntegrationTest is Origami_lov_wBTC_DAI_2xLong_IntegrationTestBase {
    using OrigamiMath for uint256;

    function test_lovToken_initialization() public {
        {
            assertEq(address(lovTokenContracts.lovToken.owner()), origamiMultisig);
            assertEq(address(lovTokenContracts.lovToken.manager()), address(lovTokenContracts.lovTokenManager));
            assertEq(lovTokenContracts.lovToken.annualPerformanceFeeBps(), Constants.PERFORMANCE_FEE_BPS);
        }

        {
            assertEq(address(lovTokenContracts.lovTokenManager.owner()), origamiMultisig);
            assertEq(address(lovTokenContracts.lovTokenManager.lovToken()), address(lovTokenContracts.lovToken));
            assertEq(lovTokenContracts.lovTokenManager.reservesBalance(), 0);

            (uint64 minDepositFeeBps, uint64 minExitFeeBps, uint64 feeLeverageFactor) = lovTokenContracts.lovTokenManager.getFeeConfig();
            assertEq(minDepositFeeBps, Constants.MIN_DEPOSIT_FEE_BPS);
            assertEq(minExitFeeBps, Constants.MIN_EXIT_FEE_BPS);
            assertEq(feeLeverageFactor, Constants.FEE_LEVERAGE_FACTOR);

            (uint128 floor, uint128 ceiling) = lovTokenContracts.lovTokenManager.userALRange();
            assertEq(floor, Constants.USER_AL_FLOOR);
            assertEq(ceiling, Constants.USER_AL_CEILING);
            (floor, ceiling) = lovTokenContracts.lovTokenManager.rebalanceALRange();
            assertEq(floor, Constants.REBALANCE_AL_FLOOR);
            assertEq(ceiling, Constants.REBALANCE_AL_CEILING);

            assertEq(address(lovTokenContracts.lovTokenManager.debtToken()), address(externalContracts.debtToken));
            assertEq(address(lovTokenContracts.lovTokenManager.reserveToken()), address(externalContracts.reserveToken));
            assertEq(address(lovTokenContracts.lovTokenManager.flashLoanProvider()), address(lovTokenContracts.flashLoanProvider));
            assertEq(address(lovTokenContracts.lovTokenManager.borrowLend()), address(lovTokenContracts.borrowLend));
            assertEq(address(lovTokenContracts.lovTokenManager.swapper()), address(lovTokenContracts.swapper));
            assertEq(address(lovTokenContracts.lovTokenManager.debtTokenToReserveTokenOracle()), address(lovTokenContracts.reserveToDebtOracle));
        }
        
        {
            assertEq(lovTokenContracts.reserveToDebtOracle.description(), "wBTC/DAI");
            assertEq(lovTokenContracts.reserveToDebtOracle.decimals(), 18);
            assertEq(lovTokenContracts.reserveToDebtOracle.precision(), 1e18);
            assertEq(address(lovTokenContracts.reserveToDebtOracle.priceOracle()), address(externalContracts.clReserveToDebtOracle));
            assertEq(lovTokenContracts.reserveToDebtOracle.pricePrecisionScaleDown(), false);
            assertEq(lovTokenContracts.reserveToDebtOracle.pricePrecisionScalar(), 1e10); // CL oracle is 8dp
            assertEq(lovTokenContracts.reserveToDebtOracle.priceStalenessThreshold(), Constants.BTC_USD_STALENESS_THRESHOLD);
            assertEq(lovTokenContracts.reserveToDebtOracle.validateRoundId(), true);
        }

        {
            assertEq(address(lovTokenContracts.flashLoanProvider.ADDRESSES_PROVIDER()), Constants.SPARK_POOL_ADDRESS_PROVIDER);
            assertEq(address(lovTokenContracts.flashLoanProvider.POOL()), Constants.SPARK_POOL);
            assertEq(lovTokenContracts.flashLoanProvider.REFERRAL_CODE(), 0);
        }

    }

    function test_lovToken_invest_success() public {
        uint256 amount = 1e8;
        uint256 amountOut = investlovToken(alice, amount);
        uint256 expectedAmountOut = amount * 99 * (10 ** (18 - Constants.WBTC_DECIMALS)) / 1e2; // deposit fees

        assertEq(amountOut, expectedAmountOut);

        {
            assertEq(lovTokenContracts.lovToken.balanceOf(alice), expectedAmountOut);
            assertEq(lovTokenContracts.lovToken.totalSupply(), expectedAmountOut);
            assertEq(externalContracts.reserveToken.balanceOf(address(lovTokenContracts.lovTokenManager)), 0);
            assertEq(lovTokenContracts.borrowLend.suppliedBalance(), amount);
            assertEq(lovTokenContracts.borrowLend.debtBalance(), 0);
            assertEq(lovTokenContracts.lovTokenManager.reservesBalance(), amount);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.SPOT_PRICE), amount);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.HISTORIC_PRICE), amount);
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), type(uint128).max);
            assertEq(lovTokenContracts.lovTokenManager.effectiveExposure(IOrigamiOracle.PriceType.SPOT_PRICE), 1e18);
            assertEq(lovTokenContracts.lovTokenManager.effectiveExposure(IOrigamiOracle.PriceType.HISTORIC_PRICE), 1e18);
        }
    }

    function test_lovToken_rebalanceDown_success() public {
        uint256 amount = 1e8;
        investlovToken(alice, amount);

        uint256 swapSlippage = 1; // 0.01%
        uint256 alSlippage = 20; // 0.2%
        (
            IOrigamiLovTokenFlashAndBorrowManager.RebalanceDownParams memory params, 
            uint256 reservesAmount
        ) = rebalanceDownParams(Constants.TARGET_AL, swapSlippage, alSlippage);

        assertEq(params.flashLoanAmount, 66_705.7643476e18); // DAI
        assertEq(reservesAmount, 1e8);  // wBTC

        // Chainlink oracle price in forked blocknumber
        uint256 expectedSwapPrice = 66_705.76434760e8;
        assertEq(expectedSwapPrice * reservesAmount * (10 ** (Constants.DAI_DECIMALS - Constants.WBTC_DECIMALS)) / (10 ** Constants.WBTC_DECIMALS), params.flashLoanAmount);

        // Oracle price is a little different. The 1inch swap data is more up to date than the oracle
        assertEq(lovTokenContracts.reserveToDebtOracle.latestPrice(IOrigamiOracle.PriceType.SPOT_PRICE, OrigamiMath.Rounding.ROUND_DOWN), 66_705.7643476e18);

        {
            vm.startPrank(origamiMultisig);
            lovTokenContracts.lovTokenManager.rebalanceDown(params);
        }
        
        {
            // Pretty close to the target (1.125) - the swap prices and fx are slightly different to actual
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), 2.00019459e18);
            assertEq(lovTokenContracts.lovTokenManager.liabilities(IOrigamiOracle.PriceType.SPOT_PRICE), 1e8);
            assertEq(lovTokenContracts.lovTokenManager.liabilities(IOrigamiOracle.PriceType.HISTORIC_PRICE), 1e8);
            uint256 expectedReserves = 2.00019459e8;
            assertEq(lovTokenContracts.lovTokenManager.reservesBalance(), expectedReserves);
            assertEq(lovTokenContracts.borrowLend.suppliedBalance(), expectedReserves);
            assertEq(lovTokenContracts.borrowLend.debtBalance(), params.flashLoanAmount);

            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.SPOT_PRICE), 1.00019459e8);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.HISTORIC_PRICE), 1.00019459e8);
        }
    }
    
    function test_lovToken_rebalanceUp_success() public {
        uint256 amount = 1e8;
        uint256 slippage = 20; // 0.2%
        investlovToken(alice, amount);
        doRebalanceDown(Constants.TARGET_AL, slippage, slippage);

        {
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), 2.000194590000000000e18);
        }

        doRebalanceUp(2.1e18, slippage, slippage);

        {
            // Pretty close to the target - swap prices and fx are slightly different to actual
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), 2.099549226311587688e18);
            assertEq(lovTokenContracts.lovTokenManager.liabilities(IOrigamiOracle.PriceType.SPOT_PRICE), 90946302);
            assertEq(lovTokenContracts.lovTokenManager.liabilities(IOrigamiOracle.PriceType.HISTORIC_PRICE), 90946302);
            assertEq(lovTokenContracts.lovTokenManager.reservesBalance(), 190946238);
            assertEq(lovTokenContracts.borrowLend.suppliedBalance(), 190946238);
            assertEq(lovTokenContracts.borrowLend.debtBalance(), 60666425574172536731044);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.SPOT_PRICE), 99999936);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.HISTORIC_PRICE), 99999936);

            // No surplus debt left over
            assertEq(externalContracts.debtToken.balanceOf(address(lovTokenContracts.lovTokenManager)), 0);
        }
    }

    function test_lovToken_fail_exit_staleOracle() public {
        uint256 amount = 1e8;
        investlovToken(alice, amount);
        
        doRebalanceDown(Constants.TARGET_AL, 20, 20);

        (IOrigamiInvestment.ExitQuoteData memory quoteData,) = lovTokenContracts.lovToken.exitQuote(
            amount / 2,
            address(externalContracts.reserveToken),
            0,
            0
        );

        // fetched from the chainlink price oracle
        uint256 expectedSwapPrice = 66_705.76434760e8;

        vm.warp(block.timestamp + 30 days);
        vm.expectRevert(abi.encodeWithSelector(IOrigamiOracle.StalePrice.selector, address(externalContracts.clReserveToDebtOracle), 1716173759, expectedSwapPrice));
        lovTokenContracts.lovToken.exitQuote(
            amount / 2,
            address(externalContracts.reserveToken),
            0,
            0
        );

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IOrigamiOracle.StalePrice.selector, address(externalContracts.clReserveToDebtOracle), 1716173759, expectedSwapPrice));
        lovTokenContracts.lovToken.exitToToken(quoteData, bob);
    }

    function test_lovToken_success_exit() public {
        uint256 amount = 1e8;
        uint256 aliceBalance = investlovToken(alice, amount);

        // calculated with decimals scaling and deposit fees
        uint256 decimalScale = (10 ** (18 - Constants.WBTC_DECIMALS));
        amount = amount * 99 / 1e2;
        assertEq(aliceBalance, amount * decimalScale);

        uint256 amountBack = exitlovToken(alice, aliceBalance/2, bob);
        assertEq(amountBack, amount / 2);

        {
            assertEq(lovTokenContracts.lovToken.balanceOf(alice), amount * decimalScale / 2);
            assertEq(lovTokenContracts.lovToken.totalSupply(), amount * decimalScale / 2);
            assertEq(externalContracts.reserveToken.balanceOf(address(lovTokenContracts.lovTokenManager)), 0);
            assertEq(lovTokenContracts.borrowLend.suppliedBalance(), 50.5e6);
            assertEq(lovTokenContracts.borrowLend.debtBalance(), 0);
            assertEq(lovTokenContracts.lovTokenManager.reservesBalance(), 50.5e6);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.SPOT_PRICE), 50.5e6);
            assertEq(lovTokenContracts.lovTokenManager.userRedeemableReserves(IOrigamiOracle.PriceType.HISTORIC_PRICE), 50.5e6);
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), type(uint128).max);
            assertEq(lovTokenContracts.lovTokenManager.effectiveExposure(IOrigamiOracle.PriceType.SPOT_PRICE), 1e18);
            assertEq(lovTokenContracts.lovTokenManager.effectiveExposure(IOrigamiOracle.PriceType.HISTORIC_PRICE), 1e18);
        }
    }

    function test_lovToken_exit_fail_al_limit() public {
        vm.prank(origamiMultisig);

        uint256 amount = 1e8;
        investlovToken(alice, amount / 2);
        uint256 bobShares = investlovToken(bob, amount / 2);
        
        doRebalanceDown(Constants.TARGET_AL, 20, 20);
        assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), 2.00019459e18);

        uint256 maxExitAmount = 0.331762559373571495e18;
        assertEq(lovTokenContracts.lovToken.maxExit(address(externalContracts.reserveToken)), maxExitAmount);

        {
            vm.startPrank(alice);       
            (IOrigamiInvestment.ExitQuoteData memory quoteData,) = lovTokenContracts.lovToken.exitQuote(
                maxExitAmount,
                address(externalContracts.reserveToken),
                0,
                0
            );

            lovTokenContracts.lovToken.exitToToken(quoteData, alice);
            assertEq(lovTokenContracts.lovTokenManager.assetToLiabilityRatio(), Constants.USER_AL_FLOOR);
        }

        // Bob can't pull any - it will revert
        {
            vm.startPrank(bob);
            (IOrigamiInvestment.ExitQuoteData memory quoteData,) = lovTokenContracts.lovToken.exitQuote(
                10,
                address(externalContracts.reserveToken),
                0,
                0
            );

            // vm.expectRevert(abi.encodeWithSelector(IOrigamiLovTokenManager.ALTooLow.selector, 1.6667e18, 1.666699999999999999e18, 1.6667e18));
            // aave v3 error: INVALID_AMOUNT = '26'; 'Amount must be greater than 0'
            vm.expectRevert(bytes(AaveErrors.INVALID_AMOUNT));
            lovTokenContracts.lovToken.exitToToken(quoteData, bob);
        }

        // Pulling a chunky amount will cause Aave to revert since there isn't enough collateral.
        {
            vm.startPrank(bob);
            (IOrigamiInvestment.ExitQuoteData memory quoteData,) = lovTokenContracts.lovToken.exitQuote(
                bobShares,
                address(externalContracts.reserveToken),
                0,
                0
            );

            vm.expectRevert(bytes(AaveErrors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD));
            lovTokenContracts.lovToken.exitToToken(quoteData, bob);
        }
    }

    function test_lovToken_shutdown() public {
        uint256 amount = 1e8;
        investlovToken(alice, amount / 2);
        investlovToken(bob, amount / 2);

        doRebalanceDown(Constants.TARGET_AL, 20, 20);

        uint256 expectedReserves = 2.00019459e8;
        uint256 decimalScale = (10 ** (18 - Constants.WBTC_DECIMALS));
        (uint256 assets, uint256 liabilities, uint256 ratio) = lovTokenContracts.lovToken.assetsAndLiabilities();
        assertEq(assets, expectedReserves);
        assertEq(liabilities, 1.000000000000000001e18 / decimalScale);
        assertEq(ratio, expectedReserves * decimalScale);

        // Repay the full balance that was borrowed. RebalanceUp for current debt balance + 1 eth extra
        uint256 swapSlippageBps = 5;
        uint256 extraBorrowAmount = 10_000e18;
        IOrigamiLovTokenFlashAndBorrowManager.RebalanceUpParams memory params;
        params.flashLoanAmount = lovTokenContracts.borrowLend.debtBalance() + extraBorrowAmount;
        (params.collateralToWithdraw, params.swapData) = dummySwapRebalanceDownQuote(params.flashLoanAmount);
        (params.flashLoanAmount, params.swapData) = dummySwapRebalanceUpQuote(params.collateralToWithdraw);
        params.flashLoanAmount = params.flashLoanAmount.subtractBps(swapSlippageBps, OrigamiMath.Rounding.ROUND_DOWN);

        params.minNewAL = 0;
        params.maxNewAL = type(uint128).max;

        vm.startPrank(origamiMultisig);

        // change the swapper as of current BTC price is very different from forked block
        lovTokenContracts.lovTokenManager.setSwapper(address(lovTokenContracts.dummySwapper));
        deal(Constants.WBTC_ADDRESS, address(lovTokenContracts.dummySwapper), 10e8);
        deal(Constants.DAI_ADDRESS, address(lovTokenContracts.dummySwapper), 1e24);

        lovTokenContracts.lovTokenManager.forceRebalanceUp(params);

        (assets, liabilities, ratio) = lovTokenContracts.lovToken.assetsAndLiabilities();
        assertEq(assets, 85028080);
        assertEq(liabilities, 0);
        assertEq(ratio, type(uint128).max);

        // No debt left, a tiny residual of reserve token which can be reclaimed.
        assertEq(lovTokenContracts.borrowLend.debtBalance(), 0);
        assertEq(lovTokenContracts.borrowLend.aaveDebtToken().balanceOf(address(lovTokenContracts.borrowLend)), 0);
        assertEq(externalContracts.debtToken.balanceOf(address(lovTokenContracts.borrowLend)), extraBorrowAmount);
    }
}

contract Origami_lov_wBTC_DAI_2xLong_IntegrationTest_PegControls is Origami_lov_wBTC_DAI_2xLong_IntegrationTestBase {
    function test_latestPrices() public {
        (uint256 spot, uint256 hist, address baseAsset, address quoteAsset) = lovTokenContracts.reserveToDebtOracle.latestPrices(
            IOrigamiOracle.PriceType.SPOT_PRICE, 
            OrigamiMath.Rounding.ROUND_UP,
            IOrigamiOracle.PriceType.HISTORIC_PRICE, 
            OrigamiMath.Rounding.ROUND_DOWN
        );
        assertEq(spot, 66_705.7643476e18);
        assertEq(hist, 66_705.7643476e18);
        assertEq(baseAsset, address(externalContracts.reserveToken));
        assertEq(quoteAsset, address(externalContracts.debtToken));
    }
}
