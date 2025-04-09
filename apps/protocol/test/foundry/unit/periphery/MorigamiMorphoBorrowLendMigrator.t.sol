pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";

import {IMorigamiFlashLoanProvider} from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorigamiBorrowAndLend} from "contracts/interfaces/common/borrowAndLend/IMorigamiBorrowAndLend.sol";

import {MorigamiBorrowLendMigrator} from "contracts/periphery/MorigamiBorrowLendMigrator.sol";
import {MorigamiMorphoBorrowAndLend} from "contracts/common/borrowAndLend/MorigamiMorphoBorrowAndLend.sol";
import {MorigamiLovTokenMorphoManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenMorphoManager.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {MorigamiMorphoFlashLoanProvider} from "contracts/common/flashLoan/MorigamiMorphoFlashLoanProvider.sol";
import {IMorpho, Id as MorphoMarketId, MarketParams as MorphoMarketParams} from "@morpho-org/morpho-blue/src/interfaces/IMorpho.sol";

contract MorigamiMorphoBorrowAndLendMigratorTest is MorigamiTest {
    MorigamiBorrowLendMigrator public migrator;

    IMorigamiFlashLoanProvider public flashLoanProvider;

    MorigamiMorphoBorrowAndLend public constant oldBorrowLend =
        MorigamiMorphoBorrowAndLend(0xDF3D394669Fe433713D170c6DE85f02E260c1c34);

    /// @notice The new Morigami borrow lend contract
    MorigamiMorphoBorrowAndLend public newBorrowLend;

    IERC20 public constant SDAI =
        IERC20(0x83F20F44975D03b1b09e64809B757c47f942BEeA);

    IERC20 public constant USDC =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address public constant MULTISIG =
        0x781B4c57100738095222bd92D37B07ed034AB696;

    MorigamiLovTokenMorphoManager public constant manager =
        MorigamiLovTokenMorphoManager(
            0xc387Db4203d81723367CFf6Bcd14Ad2099A7Fbce
        );
    MorigamiLovToken public constant lovToken =
        MorigamiLovToken(0xdE6d401E4B651F313edB7da0A11e072EEf4Ce7BE);

    address public constant MORPHO_SINGLETON =
        0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // @todo As of now, this is just going back into the same market (intended)
    // Can be updated later once the new sdai/usdc market has been created with liquidity.
    address public constant NEW_MARKET_ORACLE =
        0xd6361d441EA8Fd285F7cd8b7d406b424e50c5429;
    address public constant NEW_MARKET_IRM =
        0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint96 public constant NEW_MARKET_LLTV = 0.965e18;
    uint256 public constant NEW_MAX_SAFE_LLTV = 0.94e18;

    function setUp() public {
        fork("mainnet", 20652628);

        // Use Morpho as the flashloan provider as it has more USDC available.
        flashLoanProvider = new MorigamiMorphoFlashLoanProvider(
            MORPHO_SINGLETON
        );

        newBorrowLend = new MorigamiMorphoBorrowAndLend(
            MULTISIG,
            address(SDAI),
            address(USDC),
            MORPHO_SINGLETON,
            NEW_MARKET_ORACLE,
            NEW_MARKET_IRM,
            NEW_MARKET_LLTV,
            NEW_MAX_SAFE_LLTV
        );

        migrator = new MorigamiBorrowLendMigrator(
            MULTISIG,
            address(oldBorrowLend),
            address(newBorrowLend),
            address(flashLoanProvider)
        );

        supply();
    }

    // Have a whale supply into the new market
    function supply() internal {
        IMorpho morpho = IMorpho(MORPHO_SINGLETON);
        MorphoMarketParams memory market = MorphoMarketParams({
            loanToken: address(USDC),
            collateralToken: address(SDAI),
            oracle: NEW_MARKET_ORACLE,
            irm: NEW_MARKET_IRM,
            lltv: NEW_MARKET_LLTV
        });
        vm.startPrank(0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa);
        USDC.approve(MORPHO_SINGLETON, 1_000_000e6);
        morpho.supply(market, 1_000_000e6, 0, MULTISIG, "");
    }

    function do_migration() internal {
        // Grant access to the migrator on the old
        setExplicitAccess(
            oldBorrowLend,
            address(migrator),
            IMorigamiBorrowAndLend.repayAndWithdraw.selector,
            true
        );

        // Grant access to the migrator on the new
        setExplicitAccess(
            newBorrowLend,
            address(migrator),
            IMorigamiBorrowAndLend.supplyAndBorrow.selector,
            true
        );

        // Set the position owner on the new borrow lend to be the
        // same as on the old
        newBorrowLend.setPositionOwner(oldBorrowLend.positionOwner());

        // Execute the migration
        migrator.execute();

        // Revoke access to the migrator on the old
        setExplicitAccess(
            oldBorrowLend,
            address(migrator),
            IMorigamiBorrowAndLend.repayAndWithdraw.selector,
            false
        );

        // Revoke access to the migrator on the new
        setExplicitAccess(
            newBorrowLend,
            address(migrator),
            IMorigamiBorrowAndLend.supplyAndBorrow.selector,
            false
        );

        // Set the borrow lend contract on the lovToken manager
        // to be the new one
        manager.setBorrowLend(address(newBorrowLend));
    }

    function test_migrator_execute() public {
        // Initial token balances
        uint256 oldSuppliedBefore = oldBorrowLend.suppliedBalance();
        uint256 oldDebtBefore = oldBorrowLend.debtBalance();
        uint256 newSuppliedBefore = newBorrowLend.suppliedBalance();
        uint256 newDebtBefore = newBorrowLend.debtBalance();
        assertEq(oldSuppliedBefore, 661_728.685913179952638724e18);
        assertEq(oldDebtBefore, 664_902.742131e6);
        assertEq(newSuppliedBefore, 0);
        assertEq(newDebtBefore, 0);

        // DO THE MIGRATION
        vm.startPrank(MULTISIG);
        do_migration();

        // After migration token balances
        uint256 oldSuppliedAfter = oldBorrowLend.suppliedBalance();
        uint256 oldDebtAfter = oldBorrowLend.debtBalance();
        uint256 newSuppliedAfter = newBorrowLend.suppliedBalance();
        uint256 newDebtAfter = newBorrowLend.debtBalance();
        assertEq(oldSuppliedAfter, 0);
        assertEq(oldDebtAfter, 0);
        assertEq(newSuppliedAfter, oldSuppliedBefore);
        assertEq(newDebtAfter, oldDebtBefore);

        // Test that Alice can now borrow and it uses the new borrow lend.
        {
            (IMorigamiInvestment.InvestQuoteData memory quoteData, ) = lovToken
                .investQuote(1e18, address(SDAI), 0, 0);
            vm.startPrank(alice);
            deal(address(SDAI), alice, 1e18, false);
            SDAI.approve(address(lovToken), 1e18);
            lovToken.investWithToken(quoteData);
            assertEq(SDAI.balanceOf(alice), 0);
            assertEq(lovToken.balanceOf(alice), 0.992137295506684717e18);
        }

        // Balances updated after Alice's deposit
        newSuppliedAfter = newBorrowLend.suppliedBalance();
        newDebtAfter = newBorrowLend.debtBalance();
        assertEq(newSuppliedAfter, oldSuppliedBefore + 1e18);
        assertEq(newDebtAfter, oldDebtBefore);
    }
}
