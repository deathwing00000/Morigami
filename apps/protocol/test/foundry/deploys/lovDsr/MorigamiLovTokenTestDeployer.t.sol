pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {RepricingToken} from "contracts/common/RepricingToken.sol";
import {Range} from "contracts/libraries/Range.sol";
import {MorigamiStableChainlinkOracle} from "contracts/common/oracle/MorigamiStableChainlinkOracle.sol";
import {MorigamiCrossRateOracle} from "contracts/common/oracle/MorigamiCrossRateOracle.sol";
import {MorigamiDexAggregatorSwapper} from "contracts/common/swappers/MorigamiDexAggregatorSwapper.sol";
import {MorigamiCircuitBreakerProxy} from "contracts/common/circuitBreaker/MorigamiCircuitBreakerProxy.sol";
import {MorigamiCircuitBreakerAllUsersPerPeriod} from "contracts/common/circuitBreaker/MorigamiCircuitBreakerAllUsersPerPeriod.sol";
import {LinearWithKinkInterestRateModel} from "contracts/common/interestRate/LinearWithKinkInterestRateModel.sol";
import {MorigamiOToken} from "contracts/investments/MorigamiOToken.sol";
import {MorigamiInvestmentVault} from "contracts/investments/MorigamiInvestmentVault.sol";
import {MorigamiLendingSupplyManager} from "contracts/investments/lending/MorigamiLendingSupplyManager.sol";
import {MorigamiLendingClerk} from "contracts/investments/lending/MorigamiLendingClerk.sol";
import {MorigamiDebtToken} from "contracts/investments/lending/MorigamiDebtToken.sol";
import {MorigamiLendingRewardsMinter} from "contracts/investments/lending/MorigamiLendingRewardsMinter.sol";
import {MorigamiIdleStrategyManager} from "contracts/investments/lending/idleStrategy/MorigamiIdleStrategyManager.sol";
import {MorigamiAaveV3IdleStrategy} from "contracts/investments/lending/idleStrategy/MorigamiAaveV3IdleStrategy.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiLovTokenErc4626Manager} from "contracts/investments/lovToken/managers/MorigamiLovTokenErc4626Manager.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";

import {DummyLovTokenSwapper} from "contracts/test/investments/lovToken/DummyLovTokenSwapper.sol";
import {DummyOracle} from "contracts/test/common/DummyOracle.sol";
import {DummyIdleStrategy} from "contracts/test/investments/lovToken/DummyIdleStrategy.m.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";
import {MockSDaiToken} from "contracts/test/external/maker/MockSDaiToken.m.sol";
import {IMorigamiSwapper} from "contracts/interfaces/common/swappers/IMorigamiSwapper.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";
import {MorigamiAbstractIdleStrategy} from "contracts/investments/lending/idleStrategy/MorigamiAbstractIdleStrategy.sol";
import {IMorigamiElevatedAccess} from "contracts/interfaces/common/access/IMorigamiElevatedAccess.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";

import {MorigamiLovTokenTestConstants as Constants} from "test/foundry/deploys/lovDsr/MorigamiLovTokenTestConstants.t.sol";

struct ExternalContracts {
    IERC20 daiToken;
    IERC20 usdcToken;
    IERC4626 sDaiToken;
    IAggregatorV3Interface clDaiUsdOracle;
    IAggregatorV3Interface clUsdcUsdOracle;
}

struct OUsdcContracts {
    MorigamiInvestmentVault ovUsdc;
    MorigamiOToken oUsdc;
    MorigamiLendingSupplyManager supplyManager;
    MorigamiLendingClerk lendingClerk;
    MorigamiIdleStrategyManager idleStrategyManager;
    MorigamiAbstractIdleStrategy idleStrategy;
    MorigamiDebtToken iUsdc;
    MorigamiLendingRewardsMinter rewardsMinter;
    MorigamiCircuitBreakerProxy cbProxy;
    MorigamiCircuitBreakerAllUsersPerPeriod cbUsdcBorrow;
    MorigamiCircuitBreakerAllUsersPerPeriod cbOUsdcExit;
    LinearWithKinkInterestRateModel globalInterestRateModel;
}

struct LovTokenContracts {
    MorigamiLovToken lovDsr;
    MorigamiLovTokenErc4626Manager lovDsrManager;
    MorigamiStableChainlinkOracle daiUsdOracle;
    MorigamiStableChainlinkOracle usdcUsdOracle; // USDC = 6dp
    MorigamiStableChainlinkOracle iUsdcUsdOracle; // iUSDC = 18dp
    MorigamiCrossRateOracle daiUsdcOracle; // USDC = 6dp
    MorigamiCrossRateOracle daiIUsdcOracle; // iUSDC = 18dp
    LinearWithKinkInterestRateModel borrowerInterestRateModel;
    IMorigamiSwapper swapper;
}

/* solhint-disable max-states-count */
contract MorigamiLovTokenTestDeployer {
    address public owner;
    address public feeCollector;
    address public overlord;

    /**
     * Either forked mainnet contracts, or mocks if non-forked
     */
    IERC20 public daiToken;
    IERC20 public usdcToken;
    IERC4626 public sDaiToken;
    IAggregatorV3Interface public clDaiUsdOracle;
    IAggregatorV3Interface public clUsdcUsdOracle;
    IMorigamiSwapper public swapper;
    MorigamiAbstractIdleStrategy public idleStrategy;

    /**
     * core contracts
     */
    MorigamiCircuitBreakerProxy public cbProxy;
    TokenPrices public tokenPrices;

    /**
     * ovUSDC contracts
     */
    MorigamiInvestmentVault public ovUsdc;
    MorigamiOToken public oUsdc;
    MorigamiLendingSupplyManager public supplyManager;
    MorigamiLendingClerk public lendingClerk;
    MorigamiIdleStrategyManager public idleStrategyManager;

    MorigamiDebtToken public iUsdc;
    MorigamiLendingRewardsMinter public rewardsMinter;

    MorigamiCircuitBreakerAllUsersPerPeriod public cbUsdcBorrow;
    MorigamiCircuitBreakerAllUsersPerPeriod public cbOUsdcExit;
    LinearWithKinkInterestRateModel public globalInterestRateModel;

    /**
     * lovDSR contracts
     */
    MorigamiLovToken public lovDsr;
    MorigamiLovTokenErc4626Manager public lovDsrManager;
    MorigamiStableChainlinkOracle public origamiDaiUsdOracle;
    MorigamiStableChainlinkOracle public origamiUsdcUsdOracle; // USDC = 6dp
    MorigamiStableChainlinkOracle public origamiIUsdcUsdOracle; // iUSDC = 18dp
    MorigamiCrossRateOracle public daiUsdcOracle; // USDC = 6dp
    MorigamiCrossRateOracle public daiIUsdcOracle; // iUSDC = 18dp
    LinearWithKinkInterestRateModel public borrowerInterestRateModel;

    Range.Data public userALRange;
    Range.Data public rebalanceALRange;

    function getContracts()
        public
        view
        returns (
            ExternalContracts memory externalContracts,
            OUsdcContracts memory oUsdcContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        externalContracts.daiToken = daiToken;
        externalContracts.usdcToken = usdcToken;
        externalContracts.sDaiToken = sDaiToken;
        externalContracts.clDaiUsdOracle = clDaiUsdOracle;
        externalContracts.clUsdcUsdOracle = clUsdcUsdOracle;

        lovTokenContracts.lovDsr = lovDsr;
        lovTokenContracts.lovDsrManager = lovDsrManager;
        lovTokenContracts.daiUsdOracle = origamiDaiUsdOracle;
        lovTokenContracts.usdcUsdOracle = origamiUsdcUsdOracle;
        lovTokenContracts.iUsdcUsdOracle = origamiIUsdcUsdOracle;
        lovTokenContracts.daiUsdcOracle = daiUsdcOracle;
        lovTokenContracts.daiIUsdcOracle = daiIUsdcOracle;
        lovTokenContracts.borrowerInterestRateModel = borrowerInterestRateModel;
        lovTokenContracts.swapper = swapper;

        oUsdcContracts.ovUsdc = ovUsdc;
        oUsdcContracts.oUsdc = oUsdc;
        oUsdcContracts.supplyManager = supplyManager;
        oUsdcContracts.lendingClerk = lendingClerk;
        oUsdcContracts.idleStrategyManager = idleStrategyManager;
        oUsdcContracts.idleStrategy = idleStrategy;

        oUsdcContracts.iUsdc = iUsdc;
        oUsdcContracts.rewardsMinter = rewardsMinter;
        oUsdcContracts.cbProxy = cbProxy;
        oUsdcContracts.cbUsdcBorrow = cbUsdcBorrow;
        oUsdcContracts.cbOUsdcExit = cbOUsdcExit;
        oUsdcContracts.globalInterestRateModel = globalInterestRateModel;
    }

    function deployNonForked(
        address _owner,
        address _feeCollector,
        address _overlord
    )
        external
        returns (
            ExternalContracts memory externalContracts,
            OUsdcContracts memory oUsdcContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        owner = _owner;
        feeCollector = _feeCollector;
        overlord = _overlord;

        daiToken = new DummyMintableToken(owner, "DAI", "DAI", 18);
        usdcToken = new DummyMintableToken(owner, "USDC", "USDC", 6);
        sDaiToken = new MockSDaiToken(daiToken);
        MockSDaiToken(address(sDaiToken)).setInterestRate(
            Constants.SDAI_INTEREST_RATE
        );

        swapper = new DummyLovTokenSwapper();
        idleStrategy = new DummyIdleStrategy(owner, address(usdcToken), 10_000);

        clDaiUsdOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 1,
                answer: 1.00044127e8,
                startedAt: 0,
                updatedAtLag: 0,
                answeredInRound: 1
            }),
            8
        );
        clUsdcUsdOracle = new DummyOracle(
            DummyOracle.Answer({
                roundId: 1,
                answer: 1.00006620e8,
                startedAt: 0,
                updatedAtLag: 0,
                answeredInRound: 1
            }),
            8
        );

        _setupOUsdc();
        _setupLovDsr();
        return getContracts();
    }

    function deployForked(
        address _owner,
        address _feeCollector,
        address _overlord
    )
        external
        returns (
            ExternalContracts memory externalContracts,
            OUsdcContracts memory oUsdcContracts,
            LovTokenContracts memory lovTokenContracts
        )
    {
        owner = _owner;
        feeCollector = _feeCollector;
        overlord = _overlord;

        {
            daiToken = IERC20(Constants.DAI_ADDRESS);
            usdcToken = IERC20(Constants.USDC_ADDRESS);
            sDaiToken = IERC4626(Constants.SDAI_ADDRESS);

            swapper = new MorigamiDexAggregatorSwapper(owner);
            MorigamiDexAggregatorSwapper(address(swapper)).whitelistRouter(
                Constants.ONE_INCH_ROUTER,
                true
            );

            idleStrategy = new MorigamiAaveV3IdleStrategy(
                owner,
                address(usdcToken),
                Constants.AAVE_POOL_ADDRESS_PROVIDER
            );

            // https://data.chain.link/ethereum/mainnet/stablecoins/dai-usd
            clDaiUsdOracle = IAggregatorV3Interface(Constants.DAI_USD_ORACLE);

            // https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd
            clUsdcUsdOracle = IAggregatorV3Interface(Constants.USDC_USD_ORACLE);
        }

        _setupOUsdc();
        _setupLovDsr();
        return getContracts();
    }

    function _setupOUsdc() private {
        idleStrategyManager = new MorigamiIdleStrategyManager(
            owner,
            address(usdcToken)
        );

        iUsdc = new MorigamiDebtToken("Morigami iUSDC", "iUSDC", owner);
        cbProxy = new MorigamiCircuitBreakerProxy(owner);
        tokenPrices = new TokenPrices(30);

        oUsdc = new MorigamiOToken(owner, "Morigami USDC Token", "oUSDC");
        ovUsdc = new MorigamiInvestmentVault(
            owner,
            "Morigami USDC Vault",
            "ovUSDC",
            address(oUsdc),
            address(tokenPrices),
            Constants.OUSDC_PERFORMANCE_FEE_BPS,
            2 days // Two days vesting of reserves
        );

        supplyManager = new MorigamiLendingSupplyManager(
            owner,
            address(usdcToken),
            address(oUsdc),
            address(ovUsdc),
            address(cbProxy),
            feeCollector,
            Constants.OUSDC_EXIT_FEE_BPS
        );

        cbUsdcBorrow = new MorigamiCircuitBreakerAllUsersPerPeriod(
            owner,
            address(cbProxy),
            26 hours,
            13,
            Constants.CB_DAILY_USDC_BORROW_LIMIT
        );
        cbOUsdcExit = new MorigamiCircuitBreakerAllUsersPerPeriod(
            owner,
            address(cbProxy),
            26 hours,
            13,
            Constants.CB_DAILY_OUSDC_EXIT_LIMIT
        );

        globalInterestRateModel = new LinearWithKinkInterestRateModel(
            owner,
            Constants.GLOBAL_IR_AT_0_UR, // 5% interest rate (rate% at 0% UR)
            Constants.GLOBAL_IR_AT_100_UR, // 20% percent interest rate (rate% at 100% UR)
            Constants.UTILIZATION_RATIO_90, // 90% utilization (UR for when the kink starts)
            Constants.GLOBAL_IR_AT_KINK // 10% percent interest rate (rate% at kink% UR)
        );

        rewardsMinter = new MorigamiLendingRewardsMinter(
            owner,
            address(oUsdc),
            address(ovUsdc),
            address(iUsdc),
            Constants.OUSDC_CARRY_OVER_BPS, // Carry over 5%
            feeCollector
        );

        lendingClerk = new MorigamiLendingClerk(
            owner,
            address(usdcToken),
            address(oUsdc),
            address(idleStrategyManager),
            address(iUsdc),
            address(cbProxy),
            address(supplyManager),
            address(globalInterestRateModel)
        );

        _postDeployOusdc();
    }

    function _postDeployOusdc() private {
        // Setup the circuit breaker for daily borrows of USDC
        cbProxy.setIdentifierForCaller(address(lendingClerk), "USDC_BORROW");
        cbProxy.setCircuitBreaker(
            keccak256("USDC_BORROW"),
            address(usdcToken),
            address(cbUsdcBorrow)
        );

        // Setup the circuit breaker for exits of USDC from oUSDC
        cbProxy.setIdentifierForCaller(address(supplyManager), "OUSDC_EXIT");
        cbProxy.setCircuitBreaker(
            keccak256("OUSDC_EXIT"),
            address(oUsdc),
            address(cbOUsdcExit)
        );

        // Hook up the lendingClerk to the supplyManager
        supplyManager.setLendingClerk(address(lendingClerk));

        // Set the fee collector for the oUSDC exit fees to be the ovUSDC rewards minter
        // Exit fees are recycled into pending rewards for remaining vault users.
        supplyManager.setFeeCollector(address(rewardsMinter));

        // Hook up the supplyManager to oUsdc
        oUsdc.setManager(address(supplyManager));

        // Allow the lendingClerk to mint/burn iUSDC
        iUsdc.setMinter(address(lendingClerk), true);

        // Set the idle strategy interest rate
        lendingClerk.setIdleStrategyInterestRate(Constants.IDLE_STRATEGY_IR);

        // Allow the LendingManager allocate/withdraw from the idle strategy
        _setExplicitAccess(
            idleStrategyManager,
            address(lendingClerk),
            MorigamiIdleStrategyManager.allocate.selector,
            MorigamiIdleStrategyManager.withdraw.selector,
            true
        );

        // Allow the idle strategy manager to allocate/withdraw to the aave strategy
        _setExplicitAccess(
            idleStrategy,
            address(idleStrategyManager),
            MorigamiIdleStrategyManager.allocate.selector,
            MorigamiIdleStrategyManager.withdraw.selector,
            true
        );

        // Allow the RewardsMinter to mint new oUSDC and add as pending reserves into ovUSDC
        oUsdc.addMinter(address(rewardsMinter));
        _setExplicitAccess(
            ovUsdc,
            address(rewardsMinter),
            RepricingToken.addPendingReserves.selector,
            true
        );

        // Set the idle strategy config
        idleStrategyManager.setIdleStrategy(address(idleStrategy));
        idleStrategyManager.setThresholds(
            Constants.AAVE_STRATEGY_DEPOSIT_THRESHOLD,
            Constants.AAVE_STRATEGY_WITHDRAWAL_THRESHOLD
        );
        idleStrategyManager.setDepositsEnabled(true);
    }

    function _setupLovDsr() private {
        origamiDaiUsdOracle = new MorigamiStableChainlinkOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "DAI/USD",
                address(daiToken),
                Constants.DAI_DECIMALS,
                Constants.INTERNAL_USD_ADDRESS,
                Constants.USD_DECIMALS
            ),
            Constants.DAI_USD_HISTORIC_STABLE_PRICE,
            address(clDaiUsdOracle),
            Constants.DAI_USD_STALENESS_THRESHOLD,
            Range.Data(
                Constants.DAI_USD_MIN_THRESHOLD,
                Constants.DAI_USD_MAX_THRESHOLD
            ),
            true, // Chainlink does use roundId
            true // It does use lastUpdatedAt
        );
        origamiUsdcUsdOracle = new MorigamiStableChainlinkOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "USDC/USD",
                address(usdcToken),
                Constants.USDC_DECIMALS,
                Constants.INTERNAL_USD_ADDRESS,
                Constants.USD_DECIMALS
            ),
            Constants.USDC_USD_HISTORIC_STABLE_PRICE,
            address(clUsdcUsdOracle),
            Constants.USDC_USD_STALENESS_THRESHOLD,
            Range.Data(
                Constants.USDC_USD_MIN_THRESHOLD,
                Constants.USDC_USD_MAX_THRESHOLD
            ),
            true, // Chainlink does use roundId
            true // It does use lastUpdatedAt
        );
        origamiIUsdcUsdOracle = new MorigamiStableChainlinkOracle(
            owner,
            IMorigamiOracle.BaseOracleParams(
                "iUSDC/USD",
                // Intentionally uses the USDC token address
                // iUSDC oracle is just a proxy for the USDC price,
                // but with 18dp instead of 6
                address(usdcToken),
                Constants.IUSDC_DECIMALS,
                Constants.INTERNAL_USD_ADDRESS,
                Constants.USD_DECIMALS
            ),
            Constants.USDC_USD_HISTORIC_STABLE_PRICE,
            address(clUsdcUsdOracle),
            Constants.USDC_USD_STALENESS_THRESHOLD,
            Range.Data(
                Constants.USDC_USD_MIN_THRESHOLD,
                Constants.USDC_USD_MAX_THRESHOLD
            ),
            true,
            true
        );
        daiUsdcOracle = new MorigamiCrossRateOracle(
            IMorigamiOracle.BaseOracleParams(
                "DAI/USDC",
                address(daiToken),
                Constants.DAI_DECIMALS,
                address(usdcToken),
                Constants.USDC_DECIMALS
            ),
            address(origamiDaiUsdOracle),
            address(origamiUsdcUsdOracle),
            address(0)
        );
        daiIUsdcOracle = new MorigamiCrossRateOracle(
            IMorigamiOracle.BaseOracleParams(
                "DAI/iUSDC",
                address(daiToken),
                Constants.DAI_DECIMALS,
                // Intentionally uses the USDC token address
                // iUSDC oracle is just a proxy for the USDC price,
                // but with 18dp instead of 6
                address(usdcToken),
                Constants.IUSDC_DECIMALS
            ),
            address(origamiDaiUsdOracle),
            address(origamiIUsdcUsdOracle),
            address(0)
        );

        lovDsr = new MorigamiLovToken(
            owner,
            "Morigami lovDSR",
            "lovDSR",
            Constants.LOV_DSR_PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        lovDsrManager = new MorigamiLovTokenErc4626Manager(
            owner,
            address(daiToken),
            address(usdcToken),
            address(sDaiToken),
            address(lovDsr)
        );

        borrowerInterestRateModel = new LinearWithKinkInterestRateModel(
            owner,
            Constants.BORROWER_IR_AT_0_UR, // 10% interest rate (rate% at 0% UR)
            Constants.BORROWER_IR_AT_100_UR, // 25% percent interest rate (rate% at 100% UR)
            Constants.UTILIZATION_RATIO_90, // 90% utilization (UR for when the kink starts)
            Constants.BORROWER_IR_AT_KINK // 15% percent interest rate (rate% at kink% UR)
        );

        _postDeployLovDsr();
    }

    function _postDeployLovDsr() private {
        userALRange = Range.Data(
            Constants.USER_AL_FLOOR,
            Constants.USER_AL_CEILING
        );
        rebalanceALRange = Range.Data(
            Constants.REBALANCE_AL_FLOOR,
            Constants.REBALANCE_AL_CEILING
        );

        // Initial setup of config.
        lovDsrManager.setLendingClerk(address(lendingClerk));
        lovDsrManager.setOracle(address(daiIUsdcOracle));
        lovDsrManager.setUserALRange(userALRange.floor, userALRange.ceiling);
        lovDsrManager.setRebalanceALRange(
            rebalanceALRange.floor,
            rebalanceALRange.ceiling
        );
        lovDsrManager.setSwapper(address(swapper));
        lovDsrManager.setFeeConfig(
            Constants.LOV_DSR_MIN_DEPOSIT_FEE_BPS,
            Constants.LOV_DSR_MIN_EXIT_FEE_BPS,
            Constants.LOV_DSR_FEE_LEVERAGE_FACTOR
        );

        _setExplicitAccess(
            lovDsrManager,
            overlord,
            MorigamiLovTokenErc4626Manager.rebalanceUp.selector,
            MorigamiLovTokenErc4626Manager.rebalanceDown.selector,
            true
        );

        lovDsr.setManager(address(lovDsrManager));

        // Only needed in lovDsrManager tests so we can mint/burn
        // (ordinarily lovDSR will do this via internal fns -- but we prank using foundry)
        lovDsr.addMinter(address(lovDsr));

        lendingClerk.addBorrower(
            address(lovDsrManager),
            address(borrowerInterestRateModel),
            Constants.LOV_DSR_IUSDC_BORROW_CAP
        );
    }

    function _setExplicitAccess(
        IMorigamiElevatedAccess theContract,
        address allowedCaller,
        bytes4 fnSelector,
        bool value
    ) private {
        IMorigamiElevatedAccess.ExplicitAccess[]
            memory access = new IMorigamiElevatedAccess.ExplicitAccess[](1);
        access[0] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector, value);
        theContract.setExplicitAccess(allowedCaller, access);
    }

    function _setExplicitAccess(
        IMorigamiElevatedAccess theContract,
        address allowedCaller,
        bytes4 fnSelector1,
        bytes4 fnSelector2,
        bool value
    ) private {
        IMorigamiElevatedAccess.ExplicitAccess[]
            memory access = new IMorigamiElevatedAccess.ExplicitAccess[](2);
        access[0] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector1, value);
        access[1] = IMorigamiElevatedAccess.ExplicitAccess(fnSelector2, value);
        theContract.setExplicitAccess(allowedCaller, access);
    }
}
