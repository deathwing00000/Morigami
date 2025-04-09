pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiLendingClerk} from "contracts/interfaces/investments/lending/IMorigamiLendingClerk.sol";
import {IMorigamiLendingBorrower} from "contracts/interfaces/investments/lending/IMorigamiLendingBorrower.sol";
import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {MorigamiLendingClerk} from "contracts/investments/lending/MorigamiLendingClerk.sol";
import {MorigamiOToken} from "contracts/investments/MorigamiOToken.sol";
import {MorigamiIdleStrategyManager} from "contracts/investments/lending/idleStrategy/MorigamiIdleStrategyManager.sol";
import {MorigamiDebtToken} from "contracts/investments/lending/MorigamiDebtToken.sol";
import {MorigamiCircuitBreakerProxy} from "contracts/common/circuitBreaker/MorigamiCircuitBreakerProxy.sol";
import {MorigamiCircuitBreakerAllUsersPerPeriod} from "contracts/common/circuitBreaker/MorigamiCircuitBreakerAllUsersPerPeriod.sol";
import {MorigamiLendingClerk} from "contracts/investments/lending/MorigamiLendingClerk.sol";
import {LinearWithKinkInterestRateModel} from "contracts/common/interestRate/LinearWithKinkInterestRateModel.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";

contract MockBorrower is IMorigamiLendingBorrower {
    /* solhint-disable immutable-vars-naming */
    IERC20 public immutable asset;
    IMorigamiLendingClerk public immutable lendingClerk;

    string public constant override version = "1.0.0";
    string public constant override name = "MockBorrower";

    constructor(address _asset, address _lendingClerk) {
        asset = IERC20(_asset);
        lendingClerk = IMorigamiLendingClerk(_lendingClerk);
    }

    function checkpointAssetBalances()
        external
        view
        override
        returns (AssetBalance[] memory assetBalances)
    {
        return latestAssetBalances();
    }

    function latestAssetBalances()
        public
        view
        override
        returns (AssetBalance[] memory assetBalances)
    {
        assetBalances = new AssetBalance[](1);
        assetBalances[0] = AssetBalance(
            address(asset),
            asset.balanceOf(address(this))
        );
    }

    function borrow(uint256 amount) external {
        lendingClerk.borrow(amount, address(this));
    }
}

contract MorigamiLendingClerkTestBase is MorigamiTest {
    DummyMintableToken public usdcToken;
    MorigamiOToken public oUsdc;
    MorigamiIdleStrategyManager public idleStrategyManager;
    MorigamiDebtToken public iUsdc;
    LinearWithKinkInterestRateModel public globalInterestRateModel;
    LinearWithKinkInterestRateModel public borrowerInterestRateModel;

    MorigamiCircuitBreakerProxy public cbProxy;
    MorigamiCircuitBreakerAllUsersPerPeriod public cbOUsdcBorrow;

    address public supplyManager = makeAddr("supplyManager");

    MorigamiLendingClerk public lendingClerk;

    MockBorrower public borrower;

    bytes32 public constant BORROW = keccak256("BORROW");

    uint256 public constant UTILIZATION_RATIO_90 = 0.9e18; // 90%

    uint80 public constant GLOBAL_IR_AT_0_UR = 0.05e18; // 5%
    uint80 public constant GLOBAL_IR_AT_KINK = 0.1e18; // 10%
    uint80 public constant GLOBAL_IR_AT_100_UR = 0.2e18; // 20%

    uint80 public constant BORROWER_IR_AT_0_UR = 0.1e18; // 10%
    uint80 public constant BORROWER_IR_AT_KINK = 0.15e18; // 15%
    uint80 public constant BORROWER_IR_AT_100_UR = 0.25e18; // 25%

    uint96 public constant IDLE_STRATEGY_IR = 0.05e18; // 5%

    function setUp() public {
        usdcToken = new DummyMintableToken(
            origamiMultisig,
            "Deposit Token",
            "token",
            6
        );
        oUsdc = new MorigamiOToken(
            origamiMultisig,
            "Morigami USDC Token",
            "oUSDC"
        );

        idleStrategyManager = new MorigamiIdleStrategyManager(
            origamiMultisig,
            address(usdcToken)
        );
        iUsdc = new MorigamiDebtToken(
            "Morigami iUSDC",
            "iUSDC",
            origamiMultisig
        );

        cbProxy = new MorigamiCircuitBreakerProxy(origamiMultisig);
        cbOUsdcBorrow = new MorigamiCircuitBreakerAllUsersPerPeriod(
            origamiMultisig,
            address(cbProxy),
            26 hours,
            13,
            2_000_000e6
        );

        globalInterestRateModel = new LinearWithKinkInterestRateModel(
            origamiMultisig,
            GLOBAL_IR_AT_0_UR, // 5% interest rate (rate% at 0% UR)
            GLOBAL_IR_AT_100_UR, // 20% percent interest rate (rate% at 100% UR)
            UTILIZATION_RATIO_90, // 90% utilization (UR for when the kink starts)
            GLOBAL_IR_AT_KINK // 10% percent interest rate (rate% at kink% UR)
        );
        borrowerInterestRateModel = new LinearWithKinkInterestRateModel(
            origamiMultisig,
            BORROWER_IR_AT_0_UR, // 10% interest rate (rate% at 0% UR)
            BORROWER_IR_AT_100_UR, // 25% percent interest rate (rate% at 100% UR)
            UTILIZATION_RATIO_90, // 90% utilization (UR for when the kink starts)
            BORROWER_IR_AT_KINK // 15% percent interest rate (rate% at kink% UR)
        );

        lendingClerk = new MorigamiLendingClerk(
            origamiMultisig,
            address(usdcToken),
            address(oUsdc),
            address(idleStrategyManager),
            address(iUsdc),
            address(cbProxy),
            supplyManager,
            address(globalInterestRateModel)
        );

        borrower = new MockBorrower(address(usdcToken), address(lendingClerk));

        // Hook up access
        {
            // Setup the circuit breaker for daily borrows of USDC
            vm.startPrank(origamiMultisig);
            cbProxy.setIdentifierForCaller(address(lendingClerk), "BORROW");
            cbProxy.setCircuitBreaker(
                BORROW,
                address(usdcToken),
                address(cbOUsdcBorrow)
            );

            // Allow the LendingManager allocate/withdraw from the idle strategy
            setExplicitAccess(
                idleStrategyManager,
                address(lendingClerk),
                MorigamiIdleStrategyManager.allocate.selector,
                MorigamiIdleStrategyManager.withdraw.selector,
                true
            );

            // Allow the lendingClerk to mint iUSDC
            iUsdc.setMinter(address(lendingClerk), true);
            lendingClerk.setIdleStrategyInterestRate(IDLE_STRATEGY_IR);

            vm.stopPrank();
        }
    }

    function addBorrower(uint256 ceiling) internal {
        vm.startPrank(origamiMultisig);
        lendingClerk.addBorrower(
            address(borrower),
            address(borrowerInterestRateModel),
            ceiling
        );
    }

    function doDeposit(uint256 supplyAmount) internal {
        vm.startPrank(supplyManager);
        doMint(usdcToken, supplyManager, supplyAmount);
        usdcToken.approve(address(lendingClerk), supplyAmount);
        lendingClerk.deposit(supplyAmount);

        // A new supply will only come from an oUSDC mint
        // Needs to scale up to 1e18
        doMint(oUsdc, alice, supplyAmount * 1e12);
    }

    function doBorrow(uint256 debtCeiling, uint256 borrowAmount) internal {
        addBorrower(debtCeiling);
        borrower.borrow(borrowAmount);
    }

    function _scaleUp(uint256 amount) internal pure returns (uint256) {
        return amount * 1e12;
    }

    // To match the scale of asset -> debt, scale down the lhs and it should
    // match except for rounding
    function _scaleAndAssert(uint256 lhs, uint256 rhs) internal {
        assertApproxEqAbs(lhs / 1e12, rhs, 1);
    }
}
