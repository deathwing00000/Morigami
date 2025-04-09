pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import {MorigamiTest} from "test/foundry/MorigamiTest.sol";
import {MockSDaiToken} from "contracts/test/external/maker/MockSDaiToken.m.sol";
import {MorigamiLovToken} from "contracts/investments/lovToken/MorigamiLovToken.sol";
import {MorigamiMockLovTokenManager} from "test/foundry/mocks/investments/lovToken/MorigamiMockLovTokenManager.m.sol";
import {IMorigamiLovTokenManager} from "contracts/interfaces/investments/lovToken/managers/IMorigamiLovTokenManager.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";
import {DummyMintableToken} from "contracts/test/common/DummyMintableToken.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {Range} from "contracts/libraries/Range.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {TokenPrices} from "contracts/common/TokenPrices.sol";

/// @notice The same as MorigamiLovTokenTestBase, but uses USDC (6dp)
/// in order to test that the abstract lovToken manager works ok for non-18dp
/// reserves / deposit assets
contract MorigamiLovTokenTestBase_6dp is MorigamiTest {
    using MorigamiMath for uint256;

    DummyMintableToken public usdcToken;
    MockSDaiToken public sUsdcToken;
    MorigamiLovToken public lovToken;
    MorigamiMockLovTokenManager public manager;
    TokenPrices public tokenPrices;

    // When seeded, the vault has an extra 10% of assets
    // So each share is redeemable for 1.1 assets
    uint256 public constant VAULT_PREMIUM = 10;
    uint16 public constant MIN_DEPOSIT_FEE_BPS = 10;
    uint16 public constant MIN_EXIT_FEE_BPS = 50;
    uint24 public constant FEE_LEVERAGE_FACTOR = 15e4;
    uint48 public constant PERFORMANCE_FEE_BPS = 500;

    // 5% APR = 4.879% APY
    uint96 public constant SUSDC_INTEREST_RATE = 0.05e18;
    address public constant INTERNAL_USD_ADDRESS =
        0x000000000000000000000000000000000000115d;

    Range.Data public userALRange;
    Range.Data public rebalanceALRange;

    function setUp() public virtual {
        usdcToken = new DummyMintableToken(origamiMultisig, "USDC", "USDC", 6);
        sUsdcToken = new MockSDaiToken(usdcToken);
        sUsdcToken.setInterestRate(SUSDC_INTEREST_RATE);
        doMint(usdcToken, address(sUsdcToken), 100_000_000e6);

        tokenPrices = new TokenPrices(30);
        lovToken = new MorigamiLovToken(
            origamiMultisig,
            "Morigami LOV TOKEN",
            "lovToken",
            PERFORMANCE_FEE_BPS,
            feeCollector,
            address(tokenPrices),
            type(uint256).max
        );
        manager = new MorigamiMockLovTokenManager(
            origamiMultisig,
            address(usdcToken),
            address(sUsdcToken),
            address(lovToken)
        );

        tokenPrices.setTokenPriceFunction(
            address(usdcToken),
            abi.encodeCall(TokenPrices.scalar, (1e30))
        );
        tokenPrices.setTokenPriceFunction(
            address(sUsdcToken),
            abi.encodeCall(TokenPrices.erc4626TokenPrice, (address(sUsdcToken)))
        );
        tokenPrices.setTokenPriceFunction(
            address(lovToken),
            abi.encodeCall(TokenPrices.repricingTokenPrice, (address(lovToken)))
        );

        vm.startPrank(origamiMultisig);
        lovToken.setManager(address(manager));
        manager.setFeeConfig(
            MIN_DEPOSIT_FEE_BPS,
            MIN_EXIT_FEE_BPS,
            FEE_LEVERAGE_FACTOR
        );

        userALRange = Range.Data(1.001e18, type(uint128).max);
        rebalanceALRange = Range.Data(1.05e18, 1.15e18);

        manager.setUserALRange(userALRange.floor, userALRange.ceiling);
        manager.setRebalanceALRange(
            rebalanceALRange.floor,
            rebalanceALRange.ceiling
        );

        vm.stopPrank();
    }

    function mintSUsdc(uint256 sUsdcAmount, address to) internal {
        uint256 usdcAmount = sUsdcToken.previewMint(sUsdcAmount);
        doMint(usdcToken, to, usdcAmount);
        vm.startPrank(to);
        usdcToken.approve(address(sUsdcToken), usdcAmount);
        sUsdcToken.mint(sUsdcAmount, to);
    }

    function bootstrapSUsdc(
        uint256 amount
    ) internal returns (uint256 sharePrice) {
        doMint(usdcToken, alice, amount);
        vm.startPrank(alice);
        usdcToken.approve(address(sUsdcToken), amount);
        sUsdcToken.deposit(amount, alice);

        // Move forward a year to accrue 5% to share price
        vm.warp(block.timestamp + 365 days);

        sharePrice = sUsdcToken.convertToAssets(10 ** sUsdcToken.decimals());
    }

    function investWithSUsdc(
        uint256 sUsdcAmount,
        address to
    ) internal virtual returns (uint256) {
        mintSUsdc(sUsdcAmount, to);
        vm.startPrank(to);

        sUsdcToken.approve(address(lovToken), sUsdcAmount);

        (IMorigamiInvestment.InvestQuoteData memory quoteData, ) = lovToken
            .investQuote(sUsdcAmount, address(sUsdcToken), 0, 0);

        vm.startPrank(to);
        return lovToken.investWithToken(quoteData);
    }

    function investWithUsdc(
        uint256 usdcAmount,
        address to
    ) internal returns (uint256) {
        doMint(usdcToken, to, usdcAmount);
        vm.startPrank(to);

        usdcToken.approve(address(lovToken), usdcAmount);

        (IMorigamiInvestment.InvestQuoteData memory quoteData, ) = lovToken
            .investQuote(usdcAmount, address(usdcToken), 0, 0);

        vm.startPrank(to);
        return lovToken.investWithToken(quoteData);
    }

    function solveRebalanceDownAmount(
        address _manager,
        uint256 targetAL
    ) internal view returns (uint256 reservesAmount) {
        if (targetAL <= 1e18) revert CommonEventsAndErrors.InvalidParam();
        /*
          targetAL == (assets+X) / (liabilities+X);
          targetAL*(liabilities+X) == (assets+X)
          targetAL*liabilities + targetAL*X == assets+X
          targetAL*liabilities + targetAL*X - X == assets
          targetAL*X - X == assets - targetAL*liabilities
          X * (targetAL - 1) == assets - targetAL*liabilities
          X == (assets - targetAL*liabilities) / (targetAL - 1)
        */
        uint256 _assets = IMorigamiLovTokenManager(_manager).reservesBalance();
        uint256 _liabilities = IMorigamiLovTokenManager(_manager).liabilities(
            IMorigamiOracle.PriceType.SPOT_PRICE
        );
        uint256 _precision = 1e18;

        uint256 _netAssets = _assets -
            targetAL.mulDiv(
                _liabilities,
                _precision,
                MorigamiMath.Rounding.ROUND_UP
            );
        reservesAmount = _netAssets.mulDiv(
            _precision,
            targetAL - _precision,
            MorigamiMath.Rounding.ROUND_UP
        );
    }

    function solveRebalanceUpAmount(
        address _manager,
        uint256 targetAL
    ) internal view returns (uint256 reservesAmount) {
        if (targetAL <= 1e18) revert CommonEventsAndErrors.InvalidParam();

        /*
          targetAL == (assets-X) / (liabilities-X);
          targetAL*(liabilities-X) == (assets-X)
          targetAL*liabilities - targetAL*X == assets-X
          targetAL*X - X == targetAL*liabilities - assets
          X - targetAL*X == targetAL*liabilities - assets
          X * (targetAL - 1) == targetAL*liabilities - assets
          X = (targetAL*liabilities - assets) / (targetAL - 1)
        */

        uint256 _assets = IMorigamiLovTokenManager(_manager).reservesBalance();
        uint256 _liabilities = IMorigamiLovTokenManager(_manager).liabilities(
            IMorigamiOracle.PriceType.SPOT_PRICE
        );
        uint256 _precision = 1e18;

        uint256 _netAssets = targetAL.mulDiv(
            _liabilities,
            _precision,
            MorigamiMath.Rounding.ROUND_UP
        ) - _assets;
        reservesAmount = _netAssets.mulDiv(
            _precision,
            targetAL - _precision,
            MorigamiMath.Rounding.ROUND_UP
        );
    }

    // Increase liabilities to lower A/L
    function doRebalanceDown(
        uint256 targetAL
    ) internal virtual returns (uint256 amount) {
        amount = solveRebalanceDownAmount(address(manager), targetAL);
        mintSUsdc(amount, address(this));
        sUsdcToken.approve(address(manager), amount);
        manager.rebalanceDown(amount);
    }

    // Decrease liabilities to raise A/L
    function doRebalanceUp(
        uint256 targetAL
    ) internal virtual returns (uint256 amount) {
        amount = solveRebalanceUpAmount(address(manager), targetAL);
        manager.rebalanceUp(amount);
    }
}
