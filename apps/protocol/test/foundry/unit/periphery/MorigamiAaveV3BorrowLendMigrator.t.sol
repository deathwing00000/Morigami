pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";

import {IMorigamiFlashLoanProvider} from "contracts/interfaces/common/flashLoan/IMorigamiFlashLoanProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IMorigamiBorrowAndLend} from "contracts/interfaces/common/borrowAndLend/IMorigamiBorrowAndLend.sol";

import {MorigamiBorrowLendMigrator} from "contracts/periphery/MorigamiBorrowLendMigrator.sol";
import {MorigamiAaveV3BorrowAndLend} from "contracts/common/borrowAndLend/MorigamiAaveV3BorrowAndLend.sol";
import {IPool as IAavePool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {MorigamiLovTokenFlashAndBorrowManager} from "contracts/investments/lovToken/managers/MorigamiLovTokenFlashAndBorrowManager.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";

contract MorigamiAaveV3BorrowAndLendMigratorTest is MorigamiTest {
    MorigamiBorrowLendMigrator public migrator;

    IMorigamiFlashLoanProvider public constant flashLoanProvider =
        IMorigamiFlashLoanProvider(0x88469316c5f828b4Dfd11C4d8529CD9F96b2E006);
    MorigamiAaveV3BorrowAndLend public constant oldBorrowLend =
        MorigamiAaveV3BorrowAndLend(0xAeDddb1e7be3b22f328456479Eb8321E3eff212E);

    /// @notice The new Morigami borrow lend contract
    MorigamiAaveV3BorrowAndLend public newBorrowLend;

    IERC20 public constant WSTETH =
        IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    IERC20 public constant WETH =
        IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address public constant MULTISIG =
        0x781B4c57100738095222bd92D37B07ed034AB696;

    address public constant REWARDS_CONTROLLER =
        0x4370D3b6C9588E02ce9D22e684387859c7Ff5b34;
    address public constant SP_WETH_DEBT_TOKEN =
        0x2e7576042566f8D6990e07A1B61Ad1efd86Ae70d;

    MorigamiLovTokenFlashAndBorrowManager public constant manager =
        MorigamiLovTokenFlashAndBorrowManager(
            0xC9632e9CBdEE643Bc490572DD0750EA394E8e3a9
        );
    MorigamiLovToken public constant lovToken =
        MorigamiLovToken(0x117b36e79aDadD8ea81fbc53Bfc9CD33270d845D);

    function setUp() public {
        fork("mainnet", 20388952);

        IAavePool aavePool = oldBorrowLend.aavePool();

        newBorrowLend = new MorigamiAaveV3BorrowAndLend(
            MULTISIG,
            oldBorrowLend.supplyToken(),
            oldBorrowLend.borrowToken(),
            address(aavePool),
            uint8(aavePool.getUserEMode(address(oldBorrowLend)))
        );

        migrator = new MorigamiBorrowLendMigrator(
            MULTISIG,
            address(oldBorrowLend),
            address(newBorrowLend),
            address(flashLoanProvider)
        );
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
        uint256 oldSuppliedBefore = oldBorrowLend.aaveAToken().balanceOf(
            address(oldBorrowLend)
        );
        uint256 oldDebtBefore = oldBorrowLend.aaveDebtToken().balanceOf(
            address(oldBorrowLend)
        );
        uint256 newSuppliedBefore = newBorrowLend.aaveAToken().balanceOf(
            address(newBorrowLend)
        );
        uint256 newDebtBefore = newBorrowLend.aaveDebtToken().balanceOf(
            address(newBorrowLend)
        );
        assertEq(oldSuppliedBefore, 1_066.055929495541277088e18);
        assertEq(oldDebtBefore, 1_137.770536686386770971e18);
        assertEq(newSuppliedBefore, 0);
        assertEq(newDebtBefore, 0);

        // DO THE MIGRATION
        vm.startPrank(MULTISIG);
        do_migration();

        // After migration token balances
        uint256 oldSuppliedAfter = oldBorrowLend.aaveAToken().balanceOf(
            address(oldBorrowLend)
        );
        uint256 oldDebtAfter = oldBorrowLend.aaveDebtToken().balanceOf(
            address(oldBorrowLend)
        );
        uint256 newSuppliedAfter = newBorrowLend.aaveAToken().balanceOf(
            address(newBorrowLend)
        );
        uint256 newDebtAfter = newBorrowLend.aaveDebtToken().balanceOf(
            address(newBorrowLend)
        );
        assertEq(oldSuppliedAfter, 0);
        assertEq(oldDebtAfter, 0);
        assertEq(newSuppliedAfter, oldSuppliedBefore);
        assertEq(newDebtAfter, oldDebtBefore);

        // Test that Alice can now borrow and it uses the new borrow lend.
        {
            (IMorigamiInvestment.InvestQuoteData memory quoteData, ) = lovToken
                .investQuote(1e18, address(WSTETH), 0, 0);
            vm.startPrank(alice);
            deal(address(WSTETH), alice, 1e18, false);
            WSTETH.approve(address(lovToken), 1e18);
            lovToken.investWithToken(quoteData);
            assertEq(WSTETH.balanceOf(alice), 0);
            assertEq(lovToken.balanceOf(alice), 0.939054229462242998e18);
        }

        // Balances updated after Alice's deposit
        newSuppliedAfter = newBorrowLend.aaveAToken().balanceOf(
            address(newBorrowLend)
        );
        newDebtAfter = newBorrowLend.aaveDebtToken().balanceOf(
            address(newBorrowLend)
        );
        assertEq(newSuppliedAfter, oldSuppliedBefore + 1e18 - 1);
        assertEq(newDebtAfter, oldDebtBefore);

        // Skip forward and claim the rewards in the new borrow lend contract
        skip(30 days);
        vm.startPrank(MULTISIG);
        address[] memory assets = new address[](1);
        assets[0] = SP_WETH_DEBT_TOKEN; // Spark WETH debt token
        (
            address[] memory rewardsList,
            uint256[] memory claimedAmounts
        ) = newBorrowLend.claimAllRewards(REWARDS_CONTROLLER, assets, bob);

        assertEq(rewardsList.length, 1);
        assertEq(rewardsList[0], address(WSTETH));
        assertEq(claimedAmounts.length, 1);
        assertEq(claimedAmounts[0], 0.394257601608916027e18);
        assertEq(WSTETH.balanceOf(bob), 0.394257601608916027e18);
    }
}
