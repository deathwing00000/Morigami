pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/gmx/MorigamiGmxManager.sol)

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IGmxRewardRouter } from "contracts/interfaces/external/gmx/IGmxRewardRouter.sol";
import { IMorigamiInvestment } from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import { IMorigamiGmxManager } from "contracts/interfaces/investments/gmx/IMorigamiGmxManager.sol";
import { IMorigamiGmxEarnAccount } from "contracts/interfaces/investments/gmx/IMorigamiGmxEarnAccount.sol";
import { IMintableToken } from "contracts/interfaces/common/IMintableToken.sol";
import { IGmxVault } from "contracts/interfaces/external/gmx/IGmxVault.sol";
import { IGlpManager } from "contracts/interfaces/external/gmx/IGlpManager.sol";
import { IGmxVaultPriceFeed } from "contracts/interfaces/external/gmx/IGmxVaultPriceFeed.sol";

import { MorigamiElevatedAccess } from "contracts/common/access/MorigamiElevatedAccess.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";

/// @title Morigami GMX/GLP Manager
/// @notice Manages Morigami's GMX and GLP positions, policy decisions and rewards harvesting/compounding.
contract MorigamiGmxManager is IMorigamiGmxManager, MorigamiElevatedAccess {
    using SafeERC20 for IERC20;
    using SafeERC20 for IMintableToken;
    using MorigamiMath for uint256;

    // Note: The below (GMX.io) contracts can be found here: https://gmxio.gitbook.io/gmx/contracts

    /// @notice $GMX (GMX.io)
    IERC20 public gmxToken;

    /// @notice $GLP (GMX.io)
    IERC20 public glpToken;

    /// @notice The GMX glpManager contract, responsible for buying/selling $GLP (GMX.io)
    IGlpManager public glpManager;

    /// @notice The GMX Vault contract, required for calculating accurate quotes for buying/selling $GLP (GMX.io)
    IGmxVault public gmxVault;

    /// @notice $wrappedNative - wrapped ETH/AVAX
    address public wrappedNativeToken;

    /// @notice $oGMX - The Morigami ERC20 receipt token over $GMX
    /// Users get oGMX for initial $GMX deposits, and for each esGMX which Morigami is rewarded,
    /// minus a fee.
    IMintableToken public immutable override oGmxToken;

    /// @notice $oGLP - The Morigami ECR20 receipt token over $GLP
    /// Users get oGLP for initial $GLP deposits.
    IMintableToken public immutable override oGlpToken;

    /// @notice Percentages of oGMX rewards (minted based off esGMX rewards) that Morigami retains as a fee
    /// @dev represented as basis points
    uint256 public oGmxRewardsFeeRate;

    /// @notice Percentages of oGMX/oGLP that Morigami retains as a fee when users sell out of their position
    /// @dev represented as basis points
    uint256 public sellFeeRate;

    /// @notice Percentage of esGMX rewards that Morigami will vest into GMX (1/365 per day).
    /// The remainder is staked.
    /// @dev represented as basis points
    uint256 public esGmxVestingRate;

    /// @notice The GMX vault rewards aggregator - any harvested rewards from staked GMX/esGMX/mult points are sent here
    address public gmxRewardsAggregator;

    /// @notice The GLP vault rewards aggregator - any harvested rewards from staked GLP are sent here.
    address public glpRewardsAggregator;

    /// @notice The set of reward tokens that the GMX manager yields to users.
    /// [ ETH/AVAX, oGMX ]
    address[] public rewardTokens;

    /// @notice The address used to collect the Morigami fees.
    address public feeCollector;

    /// @notice The Morigami contract holding the majority of staked GMX/GLP/multiplier points/esGMX.
    /// @dev When users sell GMX/GLP positions are unstaked from this account.
    /// GMX positions are also deposited directly into this account (no cooldown for GMX, unlike GLP)
    IMorigamiGmxEarnAccount public primaryEarnAccount;

    /// @notice The Morigami contract holding a small amount of staked GMX/GLP/multiplier points/esGMX.
    /// @dev This account is used to accept user deposits for GLP, such that the cooldown clock isn't reset
    /// in the primary earn account (which may block any user withdrawals)
    /// Staked GLP positions are transferred to the primaryEarnAccount on a schedule (eg daily), which does
    /// not reset the cooldown clock.
    IMorigamiGmxEarnAccount public secondaryEarnAccount;

    /// @notice A set of accounts which are allowed to pause deposits/withdrawals immediately
    /// under emergency
    mapping(address => bool) public pausers;

    /// @notice The current paused/unpaused state of investments/exits.
    IMorigamiGmxManager.Paused private _paused;

    event OGmxRewardsFeeRateSet(uint256 basisPoints);
    event SellFeeRateSet(uint256 basisPoints);
    event EsGmxVestingRateSet(uint256 basisPoints);
    event RewardsAggregatorsSet(address indexed gmxRewardsAggregator, address indexed glpRewardsAggregator);
    event PrimaryEarnAccountSet(address indexed account);
    event SecondaryEarnAccountSet(address indexed account);
    event PauserSet(address indexed account, bool canPause);
    event PausedSet(Paused paused);
    event FeeCollectorSet(address indexed feeCollector);

    constructor(
        address _initialOwner,
        address _gmxRewardRouter,
        address _glpRewardRouter,
        address _oGmxTokenAddr,
        address _oGlpTokenAddr,
        address _feeCollectorAddr,
        address _primaryEarnAccount,
        address _secondaryEarnAccount
    ) MorigamiElevatedAccess(_initialOwner) {
        _initGmxContracts(_gmxRewardRouter, _glpRewardRouter);

        oGmxToken = IMintableToken(_oGmxTokenAddr);
        oGlpToken = IMintableToken(_oGlpTokenAddr);

        rewardTokens = [wrappedNativeToken, _oGmxTokenAddr, _oGlpTokenAddr];

        primaryEarnAccount = IMorigamiGmxEarnAccount(_primaryEarnAccount);
        secondaryEarnAccount = IMorigamiGmxEarnAccount(_secondaryEarnAccount);
        feeCollector = _feeCollectorAddr;
    }

    function _initGmxContracts(
        address _gmxRewardRouter, 
        address _glpRewardRouter
    ) internal {
        IGmxRewardRouter gmxRewardRouter = IGmxRewardRouter(_gmxRewardRouter);
        IGmxRewardRouter glpRewardRouter = IGmxRewardRouter(_glpRewardRouter);
        glpManager = IGlpManager(glpRewardRouter.glpManager());
        wrappedNativeToken = gmxRewardRouter.weth();
        
        gmxToken = IERC20(gmxRewardRouter.gmx());
        glpToken = IERC20(glpRewardRouter.glp());
        gmxVault = IGmxVault(glpManager.vault());
    }

    /// @dev In case any of the upstream GMX contracts are upgraded this can be re-initialized.
    function initGmxContracts(
        address _gmxRewardRouter, 
        address _glpRewardRouter
    ) external onlyElevatedAccess {
        _initGmxContracts(_gmxRewardRouter, _glpRewardRouter);
    }

    /// @notice Current status of whether investments/exits are paused
    function paused() external view override returns (IMorigamiGmxManager.Paused memory) {
        // GLP investments can also be temporarily paused if it's paused in order to 
        // transfer staked glp from secondary -> primary
        bool areSecondaryGlpInvestmentsPaused = (address(secondaryEarnAccount) == address(0))
            ? false
            : secondaryEarnAccount.glpInvestmentsPaused();
        return IMorigamiGmxManager.Paused({
            glpInvestmentsPaused: _paused.glpInvestmentsPaused || areSecondaryGlpInvestmentsPaused,
            gmxInvestmentsPaused: _paused.gmxInvestmentsPaused,
            glpExitsPaused: _paused.glpExitsPaused,
            gmxExitsPaused: _paused.gmxExitsPaused
        });
    }

    /// @notice Allow/Deny an account to pause/unpause deposits or withdrawals
    function setPauser(address account, bool canPause) external onlyElevatedAccess {
        pausers[account] = canPause;
        emit PauserSet(account, canPause);
    }

    /// @notice Pause/unpause deposits or withdrawals
    /// @dev Can only be called by allowed pausers.
    function setPaused(Paused memory updatedPaused) external {
        if (!pausers[msg.sender]) revert CommonEventsAndErrors.InvalidAddress(msg.sender);
        emit PausedSet(updatedPaused);
        _paused = updatedPaused;
    }

    /// @notice Set the fee rate Morigami takes on oGMX rewards
    /// (which are minted based off the quantity of esGMX rewards we receive)
    /// @dev represented as basis points
    function setOGmxRewardsFeeRate(uint256 basisPoints) external onlyElevatedAccess {
        if (basisPoints > MorigamiMath.BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();
        emit OGmxRewardsFeeRateSet(basisPoints);
        oGmxRewardsFeeRate = basisPoints;
    }

    /// @notice Set the proportion of esGMX that we vest whenever rewards are harvested.
    /// The remainder are staked.
    /// @dev represented as basis points
    function setEsGmxVestingRate(uint256 basisPoints) external onlyElevatedAccess {
        if (basisPoints > MorigamiMath.BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();
        emit EsGmxVestingRateSet(basisPoints);
        esGmxVestingRate = basisPoints;
    }

    /// @notice Set the proportion of fees oGMX/oGLP Morigami retains when users sell out
    /// of their position.
    /// @dev represented as basis points
    function setSellFeeRate(uint256 basisPoints) external onlyElevatedAccess {
        if (basisPoints > MorigamiMath.BASIS_POINTS_DIVISOR) revert CommonEventsAndErrors.InvalidParam();
        emit SellFeeRateSet(basisPoints);
        sellFeeRate = basisPoints;
    }

    /// @notice Set the address for where Morigami fees are sent
    function setFeeCollector(address _feeCollector) external onlyElevatedAccess {
        if (_feeCollector == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit FeeCollectorSet(_feeCollector);
        feeCollector = _feeCollector;
    }

    /// @notice Set the Morigami account responsible for holding the majority of staked GMX/GLP/esGMX/mult points on GMX.io
    function setPrimaryEarnAccount(address _primaryEarnAccount) external onlyElevatedAccess {
        if (_primaryEarnAccount == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit PrimaryEarnAccountSet(_primaryEarnAccount);
        primaryEarnAccount = IMorigamiGmxEarnAccount(_primaryEarnAccount);
    }

    /// @notice Set the Morigami account responsible for holding a smaller/initial amount of staked GMX/GLP/esGMX/mult points on GMX.io
    /// @dev This is allowed to be set to 0x, ie unset.
    function setSecondaryEarnAccount(address _secondaryEarnAccount) external onlyElevatedAccess {
        emit SecondaryEarnAccountSet(_secondaryEarnAccount);
        secondaryEarnAccount = IMorigamiGmxEarnAccount(_secondaryEarnAccount);
    }

    /// @notice Set the Morigami GMX/GLP rewards aggregators
    function setRewardsAggregators(address _gmxRewardsAggregator, address _glpRewardsAggregator) external onlyElevatedAccess {
        if (_gmxRewardsAggregator == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        if (_glpRewardsAggregator == address(0)) revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit RewardsAggregatorsSet(_gmxRewardsAggregator, _glpRewardsAggregator);
        gmxRewardsAggregator = _gmxRewardsAggregator;
        glpRewardsAggregator = _glpRewardsAggregator;
    }
    
    /// @notice The set of reward tokens we give to the rewards aggregator
    function rewardTokensList() external view override returns (address[] memory tokens) {
        return rewardTokens;
    }

    /// @notice The amount of rewards up to this block that Morigami is due to distribute to users.
    /// @param vaultType If GLP, get the reward rates for just staked GLP rewards. If GMX, get the reward rates for combined GMX/esGMX/mult points
    /// ie the net amount after Morigami has deducted it's fees.
    function harvestableRewards(IMorigamiGmxEarnAccount.VaultType vaultType) external override view returns (uint256[] memory amounts) {
        amounts = new uint256[](rewardTokens.length);

        // Pull the currently claimable amount from Morigami's staked positions at GMX.
        // Secondary earn account rewards aren't automatically harvested, so intentionally not included here.
        (uint256 nativeAmount, uint256 esGmxAmount) = primaryEarnAccount.harvestableRewards(vaultType);

        // Ignore any portions we will be retaining as fees.
        amounts[0] = nativeAmount;
        amounts[1] = esGmxAmount.subtractBps(oGmxRewardsFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        // amounts[2] is reserved for oGLP while compounding
    }

    /// @notice The current native token and oGMX reward rates per second
    /// @param vaultType If GLP, get the reward rates for just staked GLP rewards. If GMX, get the reward rates for combined GMX/esGMX/mult points
    /// @dev Based on the current total Morigami rewards, minus any portion of fees which we will take
    function projectedRewardRates(IMorigamiGmxEarnAccount.VaultType vaultType) external override view returns (uint256[] memory amounts) {
        amounts = new uint256[](rewardTokens.length);

        // Pull the reward rates from Morigami's staked positions at GMX.
        (uint256 primaryNativeRewardRate, uint256 primaryEsGmxRewardRate) = primaryEarnAccount.rewardRates(vaultType);

        // Also include any native rewards from the secondary earn account (GLP deposits)
        // as native rewards (ie ETH) from the secondary earn account are harvested and distributed to users periodically.
        // esGMX rewards are not included from the secondary earn account, as these are perpetually staked and not automatically 
        // distributed to users.
        (uint256 secondaryNativeRewardRate,) = (address(secondaryEarnAccount) == address(0))
            ? (0, 0)
            : secondaryEarnAccount.rewardRates(vaultType);

        // Ignore any portions we will be retaining as fees.
        amounts[0] = primaryNativeRewardRate + secondaryNativeRewardRate;
        amounts[1] = primaryEsGmxRewardRate.subtractBps(oGmxRewardsFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        // amounts[2] is reserved for oGLP while compounding
    }

    /** 
     * @notice Harvest any claimable rewards up to this block from GMX.io, from the primary earn account.
     * 1/ Claimed esGMX:
     *     Vest a portion, and stake the rest -- according to `esGmxVestingRate` ratio
     *     Mint oGMX 1:1 for any esGMX that has been claimed.
     * 2/ Claimed GMX (from vested esGMX):
     *     Stake the GMX at GMX.io
     * 3/ Claimed ETH/AVAX
     *     Collect a portion as protocol fees and send the rest to the reward aggregators
     * 4/ Minted oGMX (from esGMX 1:1)
     *     Collect a portion as protocol fees and send the rest to the reward aggregators
     */
    function harvestRewards() external override onlyElevatedAccess {
        // Harvest the rewards from the primary earn account which has staked positions at GMX.io
        IMorigamiGmxEarnAccount.ClaimedRewards memory claimed = primaryEarnAccount.harvestRewards(esGmxVestingRate);

        // Apply any of the newly vested GMX
        if (claimed.vestedGmx != 0) {
            _applyGmx(claimed.vestedGmx);
        }

        // Handle esGMX rewards -- mint oGMX rewards and collect fees
        uint256 totalFees;
        uint256 _fees;
        uint256 _rewards;
        {
            // Any rewards claimed from staked GMX/esGMX/mult points => GMX Rewards Aggregator
            if (claimed.esGmxFromGmx != 0) {
                (_rewards, _fees) = claimed.esGmxFromGmx.splitSubtractBps(oGmxRewardsFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
                totalFees += _fees;
                if (_rewards != 0) oGmxToken.mint(gmxRewardsAggregator, _rewards);
            }

            // Any rewards claimed from staked GLP => GLP Rewards Aggregator
            if (claimed.esGmxFromGlp != 0) {
                (_rewards, _fees) = claimed.esGmxFromGlp.splitSubtractBps(oGmxRewardsFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
                totalFees += _fees;
                if (_rewards != 0) oGmxToken.mint(glpRewardsAggregator, _rewards);
            }

            // Mint the total oGMX fees
            if (totalFees != 0) {
                oGmxToken.mint(feeCollector, totalFees);
            }
        }

        // Handle ETH/AVAX rewards
        _processNativeRewards(claimed);
    }

    function _processNativeRewards(IMorigamiGmxEarnAccount.ClaimedRewards memory claimed) internal {
        // Any rewards claimed from staked GMX/esGMX/mult points => GMX Investment Manager
        if (claimed.wrappedNativeFromGmx != 0) {
            IERC20(wrappedNativeToken).safeTransfer(gmxRewardsAggregator, claimed.wrappedNativeFromGmx);
        }

        // Any rewards claimed from staked GLP => GLP Investment Manager
        if (claimed.wrappedNativeFromGlp != 0) {
            IERC20(wrappedNativeToken).safeTransfer(glpRewardsAggregator, claimed.wrappedNativeFromGlp);
        }
    }

    /** 
     * @notice Claim any ETH/AVAX rewards from the secondary earn account,
     * and perpetually stake any esGMX/multiplier points.
     */
    function harvestSecondaryRewards() external override onlyElevatedAccess {
        IMorigamiGmxEarnAccount.ClaimedRewards memory claimed = secondaryEarnAccount.handleRewards(
            IMorigamiGmxEarnAccount.HandleGmxRewardParams({
                shouldClaimGmx: false,
                shouldStakeGmx: false,
                shouldClaimEsGmx: true,
                shouldStakeEsGmx: true,
                shouldStakeMultiplierPoints: true,
                shouldClaimWeth: true
            })
        );

        _processNativeRewards(claimed);
    }

    /// @notice The amount of native ETH/AVAX rewards up to this block that the secondary earn account is due to distribute to users.
    /// @param vaultType If GLP, get the reward rates for just staked GLP rewards. If GMX, get the reward rates for combined GMX/esGMX/mult points
    /// ie the net amount after Morigami has deducted it's fees.
    function harvestableSecondaryRewards(IMorigamiGmxEarnAccount.VaultType vaultType) external view returns (uint256[] memory amounts) {
        amounts = new uint256[](rewardTokens.length);

        // esGMX rewards aren't harvestable from the secondary earn account as they are perpetually staked - so intentionally not included here.
        (amounts[0],) = secondaryEarnAccount.harvestableRewards(vaultType);
    }

    /// @notice Apply any unstaked GMX (eg from user deposits) of $GMX into Morigami's GMX staked position.
    function applyGmx(uint256 _amount) external onlyElevatedAccess {
        if (_amount == 0) revert CommonEventsAndErrors.ExpectedNonZero();
        _applyGmx(_amount);
    }

    function _applyGmx(uint256 _amount) internal {
        gmxToken.safeTransfer(address(primaryEarnAccount), _amount);
        primaryEarnAccount.stakeGmx(_amount);
    }

    /// @notice The set of accepted tokens which can be used to invest/exit into oGMX.
    function acceptedOGmxTokens() external view override returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(gmxToken);
    }

    /**
     * @notice Get a quote to buy the oGMX using GMX.
     * @param fromTokenAmount How much of GMX to invest with
     * @param fromToken This must be the address of the GMX token
     * @param maxSlippageBps The maximum acceptable slippage of the received investment amount
     * @param deadline The maximum deadline to execute the exit.
     * @return quoteData The quote data, including any other quote params required for this investment type. To be passed through when executing the quote.
     * @return investFeeBps [GMX.io's fee when depositing with `fromToken`]
     */
    function investOGmxQuote(
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external override view returns (
        IMorigamiInvestment.InvestQuoteData memory quoteData, 
        uint256[] memory investFeeBps
    ) {
        if (fromToken != address(gmxToken)) revert CommonEventsAndErrors.InvalidToken(fromToken);
        if (fromTokenAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();

        // oGMX is minted 1:1, no fees or slippage
        quoteData = IMorigamiInvestment.InvestQuoteData({
            fromToken: fromToken,
            fromTokenAmount: fromTokenAmount,
            maxSlippageBps: maxSlippageBps,
            deadline: deadline,
            expectedInvestmentAmount: fromTokenAmount,
            minInvestmentAmount: fromTokenAmount,
            underlyingInvestmentQuoteData: "" // No extra underlyingInvestmentQuoteData
        });
        
        investFeeBps = new uint256[](0);
    }

    /** 
      * @notice User buys oGMX with an amount GMX.
      * @param quoteData The quote data received from investQuote()
      * @return investmentAmount The actual number of receipt tokens received, inclusive of any fees.
      */
    function investOGmx(
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external override onlyElevatedAccess returns (
        uint256 investmentAmount
    ) {
        if (_paused.gmxInvestmentsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.fromToken != address(gmxToken)) revert CommonEventsAndErrors.InvalidToken(quoteData.fromToken);

        // Transfer the GMX straight to the primary earn account which stakes the GMX at GMX.io
        // NB: There is no cooldown when transferring GMX, so using the primary earn account for deposits is fine.
        gmxToken.safeTransfer(address(primaryEarnAccount), quoteData.fromTokenAmount);
        primaryEarnAccount.stakeGmx(quoteData.fromTokenAmount);

        // User gets 1:1 oGMX for the GMX provided.
        investmentAmount = quoteData.fromTokenAmount;
    }

    /**
     * @notice Get a quote to sell oGMX to GMX.
     * @param investmentTokenAmount The amount of oGMX to sell
     * @param toToken This must be the address of the GMX token
     * @param maxSlippageBps The maximum acceptable slippage of the received `toToken`
     * @param deadline The maximum deadline to execute the exit.
     * @return quoteData The quote data, including any other quote params required for this investment type. To be passed through when executing the quote.
     * @return exitFeeBps [Morigami's exit fee]
     */
    function exitOGmxQuote(
        uint256 investmentTokenAmount, 
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external override view returns (
        IMorigamiInvestment.ExitQuoteData memory quoteData, 
        uint256[] memory exitFeeBps
    ) {
        if (investmentTokenAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();
        if (toToken != address(gmxToken)) revert CommonEventsAndErrors.InvalidToken(toToken);

        uint256 _sellFeeRate = sellFeeRate;

        // oGMX is sold 1:1 to GMX, no slippage, with exit fee
        quoteData.investmentTokenAmount = investmentTokenAmount;
        quoteData.toToken = toToken;
        quoteData.maxSlippageBps = maxSlippageBps;
        quoteData.deadline = deadline;
        quoteData.expectedToTokenAmount = investmentTokenAmount.subtractBps(_sellFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        quoteData.minToTokenAmount = quoteData.expectedToTokenAmount;
        // No extra underlyingInvestmentQuoteData

        exitFeeBps = new uint256[](1);
        exitFeeBps[0] = _sellFeeRate;
    }
    
    /** 
      * @notice Sell oGMX to receive GMX. 
      * @param quoteData The quote data received from exitQuote()
      * @param recipient The receiving address of the GMX
      * @return toTokenAmount The number of GMX tokens received upon selling the oGMX.
      * @return toBurnAmount The number of oGMX to be burnt after exiting this position
      */
    function exitOGmx(
        IMorigamiInvestment.ExitQuoteData memory quoteData,
        address recipient
    ) external override onlyElevatedAccess returns (uint256 toTokenAmount, uint256 toBurnAmount) {
        if (_paused.gmxExitsPaused) revert CommonEventsAndErrors.IsPaused();
        if (quoteData.toToken != address(gmxToken)) revert CommonEventsAndErrors.InvalidToken(quoteData.toToken);

        (uint256 nonFees, uint256 fees) = quoteData.investmentTokenAmount.splitSubtractBps(
            sellFeeRate, 
            MorigamiMath.Rounding.ROUND_DOWN
        );
        toTokenAmount = nonFees;

        // Send the oGlp fees to the fee collector
        if (fees != 0) {
            oGmxToken.safeTransfer(feeCollector, fees);
        }

        if (nonFees != 0) {
            // Burn the remaining oGmx
            toBurnAmount = nonFees;

            // Unstake the GMX - NB this burns any multiplier points
            primaryEarnAccount.unstakeGmx(nonFees);

            // Send the GMX to the recipient
            gmxToken.safeTransfer(recipient, nonFees);
        }
    }

    /// @notice The set of whitelisted GMX.io tokens which can be used to buy GLP (and hence oGLP)
    /// @dev Native tokens (ETH/AVAX) and using staked GLP can also be used.
    function acceptedGlpTokens() external view override returns (address[] memory tokens) {
        uint256 length = gmxVault.allWhitelistedTokensLength();
        tokens = new address[](length + 2);

        // Add in the GMX.io whitelisted tokens
        // uint256 tokenIdx;
        uint256 i;
        for (; i < length; ++i) {
            tokens[i] = gmxVault.allWhitelistedTokens(i);
        }

        // ETH/AVAX is at [length-1 + 1]. Already instantiated as 0x
        // staked GLP is at [length-1 + 2]
        tokens[i+1] = address(primaryEarnAccount.stakedGlp());
    }

    function applySlippage(uint256 quote, uint256 slippageBps) internal pure returns (uint256) {
        // A special case for slippage == 0% within ovGMX/ovGLP, where it also represents 'ignore any slippage'
        // The min amount expected should be 0 in this case.
        unchecked {
            return slippageBps != 0 && slippageBps < MorigamiMath.BASIS_POINTS_DIVISOR
                ? MorigamiMath.mulDiv(
                    quote, 
                    (MorigamiMath.BASIS_POINTS_DIVISOR - slippageBps),
                    MorigamiMath.BASIS_POINTS_DIVISOR,
                    MorigamiMath.Rounding.ROUND_UP
                ) : 0;
        }
    }

    /**
     * @notice Get a quote to buy the oGLP using one of the approved tokens, inclusive of GMX.io fees.
     * @dev The 0x0 address can be used for native chain ETH/AVAX
     * @param fromTokenAmount How much of `fromToken` to invest with
     * @param fromToken What ERC20 token to purchase with. This must be one of `acceptedInvestTokens`
     * @return quoteData The quote data, including any other quote params required for the underlying investment type. To be passed through when executing the quote.
     * @return investFeeBps [GMX.io's fee when depositing with `fromToken`]
     */
    function investOGlpQuote(
        uint256 fromTokenAmount, 
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external view override returns (
        IMorigamiInvestment.InvestQuoteData memory quoteData, 
        uint256[] memory investFeeBps
    ) {
        if (fromTokenAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();

        quoteData.fromToken = fromToken;
        quoteData.fromTokenAmount = fromTokenAmount;
        quoteData.maxSlippageBps = maxSlippageBps;
        quoteData.deadline = deadline;
        // No extra underlyingInvestmentQuoteData

        if (fromToken == address(primaryEarnAccount.stakedGlp())) {
            quoteData.expectedInvestmentAmount = fromTokenAmount; // 1:1 for staked GLP
            quoteData.minInvestmentAmount = fromTokenAmount; // No slippage
            investFeeBps = new uint256[](1); // investFeeBps[0]=0
        } else {
            // GMX.io don't provide on-contract external functions to obtain the quote. Logic extracted from:
            // https://github.com/gmx-io/gmx-contracts/blob/83bd5c7f4a1236000e09f8271d58206d04d1d202/contracts/core/GlpManager.sol#L160
            investFeeBps = new uint256[](1);
            uint256 aumInUsdg = glpManager.getAumInUsdg(true); // Assets Under Management
            uint256 glpSupply = IERC20(glpToken).totalSupply();

            fromToken = (fromToken == address(0)) ? wrappedNativeToken : fromToken;
            uint256 expectedUsdg;
            (investFeeBps[0], expectedUsdg) = buyUsdgQuote(
                fromTokenAmount,
                fromToken
            );
            
            // oGLP is minted 1:1 to the amount of GLP received.
            quoteData.expectedInvestmentAmount = (aumInUsdg == 0) ? expectedUsdg : expectedUsdg * glpSupply / aumInUsdg;
            quoteData.minInvestmentAmount = applySlippage(quoteData.expectedInvestmentAmount, maxSlippageBps);
        }
    }

    /** 
      * @notice User buys oGLP with an amount of one of the approved ERC20 tokens. 
      * @param fromToken The token override to invest with. May be different from the `quoteData.fromToken`
      * @param quoteData The quote data received from investQuote()
      * @return investmentAmount The actual number of receipt tokens received, inclusive of any fees.
      */
    function investOGlp(
        address fromToken,
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external override onlyElevatedAccess returns (
        uint256 investmentAmount
    ) {
        if (_paused.glpInvestmentsPaused) revert CommonEventsAndErrors.IsPaused();

        if (fromToken == address(primaryEarnAccount.stakedGlp())) {
            // Pull staked GLP tokens from the user and transfer directly to the primary Morigami earn account contract, responsible for staking.
            // This doesn't reset the cooldown clock for withdrawals, so it's ok to send directly to the primary earn account.
            IERC20(fromToken).safeTransfer(address(primaryEarnAccount), quoteData.fromTokenAmount);
            investmentAmount = quoteData.fromTokenAmount;
        } else {
            if (!gmxVault.whitelistedTokens(fromToken)) revert CommonEventsAndErrors.InvalidToken(fromToken);

            // Pull ERC20 tokens from the user and send to the secondary Morigami earn account contract which purchases GLP on GMX.io and stakes it
            // This DOES reset the cooldown clock for withdrawals, so the secondary account is used in order 
            // to avoid withdrawals blocking from cooldown in the primary account.
            IERC20(fromToken).safeTransfer(address(secondaryEarnAccount), quoteData.fromTokenAmount);

            // Safe to assume the minUsdg=0, as we only care that we get the min GLP amount out.
            investmentAmount = secondaryEarnAccount.mintAndStakeGlp(
                quoteData.fromTokenAmount, fromToken, 0, quoteData.minInvestmentAmount
            );
        }
    }

    /**
     * @notice Get a quote to sell oGLP to receive one of the accepted tokens.
     * @dev The 0x0 address can be used for native chain ETH/AVAX
     * @param investmentTokenAmount The amount of oGLP to sell
     * @param toToken The token to receive when selling. This must be one of `acceptedExitTokens`
     * @return quoteData The quote data, including any other quote params required for this investment type. To be passed through when executing the quote.
     * @return exitFeeBps [Morigami's exit fee, GMX.io's fee when selling to `toToken`]
     */
    function exitOGlpQuote(
        uint256 investmentTokenAmount, 
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    ) external override view returns (
        IMorigamiInvestment.ExitQuoteData memory quoteData, 
        uint256[] memory exitFeeBps
    ) {
        if (investmentTokenAmount == 0) revert CommonEventsAndErrors.ExpectedNonZero();

        quoteData.investmentTokenAmount = investmentTokenAmount;
        quoteData.toToken = toToken;
        quoteData.maxSlippageBps = maxSlippageBps;
        quoteData.deadline = deadline;
        // No extra underlyingInvestmentQuoteData

        uint256 _sellFeeRate = sellFeeRate;
        exitFeeBps = new uint256[](2);  // [Morigami's exit fee, GMX's exit fee]
        exitFeeBps[0] = _sellFeeRate;
        uint256 glpAmount = investmentTokenAmount.subtractBps(_sellFeeRate, MorigamiMath.Rounding.ROUND_DOWN);
        if (glpAmount == 0) return (quoteData, exitFeeBps);

        if (toToken == address(primaryEarnAccount.stakedGlp())) {
            // No GMX related fees for staked GLP transfers
            quoteData.expectedToTokenAmount = glpAmount;
            quoteData.minToTokenAmount = glpAmount; // No slippage
        } else {
            // GMX.io don't provide on-contract external functions to obtain the quote. Logic extracted from:
            // https://github.com/gmx-io/gmx-contracts/blob/83bd5c7f4a1236000e09f8271d58206d04d1d202/contracts/core/GlpManager.sol#L183
            uint256 aumInUsdg = glpManager.getAumInUsdg(false); // Assets Under Management
            uint256 glpSupply = IERC20(glpToken).totalSupply();
            uint256 usdgAmount = (glpSupply == 0) ? 0 : glpAmount * aumInUsdg / glpSupply;
            
            toToken = (toToken == address(0)) ? wrappedNativeToken : toToken;
            (exitFeeBps[1], quoteData.expectedToTokenAmount) = sellUsdgQuote(
                usdgAmount,
                toToken
            );
            quoteData.minToTokenAmount = applySlippage(quoteData.expectedToTokenAmount, maxSlippageBps);
        }
    }

    /** 
      * @notice Sell oGLP to receive one of the accepted tokens. 
      * @param toToken The token override to invest with. May be different from the `quoteData.toToken`
      * @param quoteData The quote data received from exitQuote()
      * @param recipient The receiving address of the `toToken`
      * @return toTokenAmount The number of `toToken` tokens received upon selling the oGLP
      * @return toBurnAmount The number of oGLP to be burnt after exiting this position
      */
    function exitOGlp(
        address toToken,
        IMorigamiInvestment.ExitQuoteData calldata quoteData,
        address recipient
    ) external override onlyElevatedAccess returns (uint256 toTokenAmount, uint256 toBurnAmount) {
        if (_paused.glpExitsPaused) revert CommonEventsAndErrors.IsPaused();

        (uint256 nonFees, uint256 fees) = quoteData.investmentTokenAmount.splitSubtractBps(
            sellFeeRate, 
            MorigamiMath.Rounding.ROUND_DOWN
        );

        // Send the oGlp fees to the fee collector
        if (fees != 0) {
            oGlpToken.safeTransfer(feeCollector, fees);
        }

        if (nonFees != 0) {
            // Burn the remaining oGlp
            toBurnAmount = nonFees;

            if (toToken == address(primaryEarnAccount.stakedGlp())) {
                // Transfer the remaining staked GLP to the recipient
                primaryEarnAccount.transferStakedGlp(
                    nonFees,
                    recipient
                );
                toTokenAmount = nonFees;
            } else {
                if (!gmxVault.whitelistedTokens(toToken)) revert CommonEventsAndErrors.InvalidToken(toToken);

                // Sell from the primary earn account and send the resulting token to the recipient.
                toTokenAmount = primaryEarnAccount.unstakeAndRedeemGlp(
                    nonFees,
                    toToken,
                    quoteData.minToTokenAmount,
                    recipient
                );
            }
        }
    }

    function buyUsdgQuote(uint256 fromAmount, address fromToken) internal view returns (
        uint256 feeBasisPoints,
        uint256 usdgAmountOut
    ) {
        // Used as part of the quote to buy GLP. Forked from:
        // https://github.com/gmx-io/gmx-contracts/blob/83bd5c7f4a1236000e09f8271d58206d04d1d202/contracts/core/Vault.sol#L452
        if (!gmxVault.whitelistedTokens(fromToken)) revert CommonEventsAndErrors.InvalidToken(fromToken);
        uint256 price = IGmxVaultPriceFeed(gmxVault.priceFeed()).getPrice(fromToken, false, true, true);
        uint256 pricePrecision = gmxVault.PRICE_PRECISION();
        address usdg = gmxVault.usdg();
        uint256 usdgAmount = fromAmount * price / pricePrecision;
        usdgAmount = gmxVault.adjustForDecimals(usdgAmount, fromToken, usdg);

        feeBasisPoints = getFeeBasisPoints(
            fromToken, usdgAmount, 
            true  // true for buy, false for sell
        );

        uint256 amountAfterFees = fromAmount.subtractBps(feeBasisPoints, MorigamiMath.Rounding.ROUND_DOWN);
        usdgAmountOut = gmxVault.adjustForDecimals(amountAfterFees * price / pricePrecision, fromToken, usdg);
    }

    function sellUsdgQuote(
        uint256 usdgAmount, address toToken
    ) internal view returns (uint256 feeBasisPoints, uint256 amountOut) {
        // Used as part of the quote to sell GLP. Forked from:
        // https://github.com/gmx-io/gmx-contracts/blob/83bd5c7f4a1236000e09f8271d58206d04d1d202/contracts/core/Vault.sol#L484
        if (usdgAmount == 0) return (feeBasisPoints, amountOut);
        if (!gmxVault.whitelistedTokens(toToken)) revert CommonEventsAndErrors.InvalidToken(toToken);
        uint256 pricePrecision = gmxVault.PRICE_PRECISION();
        uint256 price = IGmxVaultPriceFeed(gmxVault.priceFeed()).getPrice(toToken, true, true, true);
        address usdg = gmxVault.usdg();
        uint256 redemptionAmount = gmxVault.adjustForDecimals(usdgAmount * pricePrecision / price, usdg, toToken);

        feeBasisPoints = getFeeBasisPoints(
            toToken, usdgAmount,
            false  // true for buy, false for sell
        );

        amountOut = redemptionAmount.subtractBps(feeBasisPoints, MorigamiMath.Rounding.ROUND_DOWN);
    }

    function getFeeBasisPoints(address _token, uint256 _usdgDelta, bool _increment) internal view returns (uint256) {
        // Used as part of the quote to buy/sell GLP. Forked from:
        // https://github.com/gmx-io/gmx-contracts/blob/83bd5c7f4a1236000e09f8271d58206d04d1d202/contracts/core/VaultUtils.sol#L143
        uint256 feeBasisPoints = gmxVault.mintBurnFeeBasisPoints();
        uint256 taxBasisPoints = gmxVault.taxBasisPoints();
        if (!gmxVault.hasDynamicFees()) { return feeBasisPoints; }

        // The GMX.io website sell quotes are slightly off when calculating the fee. When actually selling, 
        // the code already has the sell amount (_usdgDelta) negated from initialAmount and usdgSupply,
        // however when getting a quote, it doesn't have this amount taken off - so we get slightly different results.
        // To have the quotes match the exact amounts received when selling, this tweak is required.
        // https://github.com/gmx-io/gmx-contracts/issues/28
        uint256 initialAmount = gmxVault.usdgAmounts(_token);
        uint256 usdgSupply = IERC20(gmxVault.usdg()).totalSupply();
        if (!_increment) {
            initialAmount = (_usdgDelta > initialAmount) ? 0 : initialAmount - _usdgDelta;
            usdgSupply = (_usdgDelta > usdgSupply) ? 0 : usdgSupply - _usdgDelta;
        }
        // End tweak

        uint256 nextAmount = initialAmount + _usdgDelta;
        if (!_increment) {
            nextAmount = _usdgDelta > initialAmount ? 0 : initialAmount - _usdgDelta;
        }

        uint256 targetAmount = (usdgSupply == 0)
            ? 0
            : gmxVault.tokenWeights(_token) * usdgSupply / gmxVault.totalTokenWeights();
        if (targetAmount == 0) { return feeBasisPoints; }

        uint256 initialDiff = initialAmount > targetAmount ? initialAmount - targetAmount : targetAmount - initialAmount;
        uint256 nextDiff = nextAmount > targetAmount ? nextAmount - targetAmount : targetAmount - nextAmount;

        // action improves relative asset balance
        if (nextDiff < initialDiff) {
            uint256 rebateBps = taxBasisPoints * initialDiff / targetAmount;
            return rebateBps > feeBasisPoints ? 0 : feeBasisPoints - rebateBps;
        }

        uint256 averageDiff = (initialDiff + nextDiff) / 2;
        if (averageDiff > targetAmount) {
            averageDiff = targetAmount;
        }

        uint256 taxBps = taxBasisPoints * averageDiff / targetAmount;
        return feeBasisPoints + taxBps;
    }

    /// @notice Owner can recover tokens
    function recoverToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyElevatedAccess {
        // This contract doesn't hold any tokens under normal operations.
        // So no checks on valid tokens to recover are required.
        emit CommonEventsAndErrors.TokenRecovered(_to, _token, _amount);
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
