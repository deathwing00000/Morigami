pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/gmx/MorigamiGmxRewardsAggregator.sol)

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IMorigamiInvestmentManager } from "contracts/interfaces/investments/IMorigamiInvestmentManager.sol";
import { IMorigamiInvestmentVault } from "contracts/interfaces/investments/IMorigamiInvestmentVault.sol";
import { IMorigamiGmxManager } from "contracts/interfaces/investments/gmx/IMorigamiGmxManager.sol";
import { IMorigamiInvestment } from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import { IMorigamiGmxEarnAccount } from "contracts/interfaces/investments/gmx/IMorigamiGmxEarnAccount.sol";
import { CommonEventsAndErrors } from "contracts/libraries/CommonEventsAndErrors.sol";
import { MorigamiMath } from "contracts/libraries/MorigamiMath.sol";
import { MorigamiElevatedAccess } from "contracts/common/access/MorigamiElevatedAccess.sol";

/// @title Morigami GMX/GLP Rewards Aggregator
/// @notice Manages the collation and selection of GMX.io rewards sources to the correct Morigami investment vault.
/// ie the Morigami GMX vault and the Morigami GLP vault
/// @dev This implements the IMorigamiInvestmentManager interface -- the Morigami GMX/GLP Rewards Distributor 
/// calls to harvest aggregated rewards.
contract MorigamiGmxRewardsAggregator is IMorigamiInvestmentManager, MorigamiElevatedAccess {
    using SafeERC20 for IERC20;
    using MorigamiMath for uint256;

    /**
     * @notice The type of vault this aggregator is for - either GLP or GMX.
     * The ovGLP vault gets compounding rewards from:
     *    1/ 'staked GLP'
     * The ovGMX vault gets compounding rewards from:
     *    2/ 'staked GMX'
     *    3/ 'staked GMX/esGMX/mult points' where that GMX/esGMX/mult points was earned from the staked GMX (2)
     *    4/ 'staked GMX/esGMX/mult points' where that GMX/esGMX/mult points was earned from the staked GLP (1)
     */
    IMorigamiGmxEarnAccount.VaultType public vaultType;

    /// @notice The Morigami contract managing the holdings of staked GMX derived rewards
    /// @dev The GMX Vault needs to pick staked GMX/esGMX/mult point rewards from both GMX Manager and also GLP Manager 
    IMorigamiGmxManager public gmxManager;

    /// @notice The Morigami contract managing the holdings of staked GLP derived rewards
    /// @dev The GLP Vault picks staked GLP rewards from the GLP manager. 
    /// The GMX vault picks staked GMX/esGMX/mult points from the GLP Manager
    IMorigamiGmxManager public glpManager;

    /// @notice $wrappedNative - wrapped ETH/AVAX
    IERC20 public immutable wrappedNativeToken;

    /// @notice The address of the 0x proxy for GMX <--> ETH swaps
    address public immutable zeroExProxy;

    /// @notice The set of reward tokens that the GMX manager yields to users.
    /// [ ETH/AVAX, oGMX ]
    address[] public rewardTokens;

    /// @notice The ovToken that rewards will compound into when harvested/swapped. 
    IMorigamiInvestmentVault public immutable ovToken;

    /// @notice The last timestamp that the harvest successfully ran.
    uint256 public lastHarvestedAt;

    /// @notice The address used to collect the Morigami performance fees.
    address public performanceFeeCollector;

    /// @notice Parameters required when compounding ovGMX rewards
    struct HarvestGmxParams {
        /// @dev The required calldata to swap from wETH/wAVAX -> GMX
        bytes nativeToGmxSwapData;

        /// @dev The quote to invest in oGMX with GMX
        IMorigamiInvestment.InvestQuoteData oGmxInvestQuoteData;

        /// @dev How much percentage of the oGMX to add as reserves to ovGMX
        /// 10_000 == 100%
        uint256 addToReserveAmountPct;
    }

    /// @notice Parameters required when compounding ovGLP rewards
    struct HarvestGlpParams {
        /// @dev The quote to exit from oGMX -> GMX
        IMorigamiInvestment.ExitQuoteData oGmxExitQuoteData;

        /// @dev The required calldata to swap from GMX -> wETH/wAVAX
        bytes gmxToNativeSwapData;

        /// @dev The quote to invest in oGLP with wETH/wAVAX
        IMorigamiInvestment.InvestQuoteData oGlpInvestQuoteData;

        /// @dev How much of the oGLP to add as reserves to ovGLP
        /// 10_000 == 100%
        uint256 addToReserveAmountPct;
    }
    
    event MorigamiGmxManagersSet(IMorigamiGmxEarnAccount.VaultType _vaultType, address indexed gmxManager, address indexed glpManager);
    event CompoundOvGmx(HarvestGmxParams harvestParams);
    event CompoundOvGlp(HarvestGlpParams harvestParams);
    event PerformanceFeeCollectorSet(address indexed performanceFeeCollector);

    error UnknownSwapError(bytes result);

    constructor(
        address _initialOwner,
        IMorigamiGmxEarnAccount.VaultType _vaultType,
        address _gmxManager,
        address _glpManager,
        address _ovToken,
        address _wrappedNativeToken,
        address _zeroExProxy,
        address _performanceFeeCollector
    ) MorigamiElevatedAccess(_initialOwner) {
        vaultType = _vaultType;
        gmxManager = IMorigamiGmxManager(_gmxManager);
        glpManager = IMorigamiGmxManager(_glpManager);
        rewardTokens = vaultType == IMorigamiGmxEarnAccount.VaultType.GLP
            ? glpManager.rewardTokensList() 
            : gmxManager.rewardTokensList();
        ovToken = IMorigamiInvestmentVault(_ovToken);
        wrappedNativeToken = IERC20(_wrappedNativeToken);
        zeroExProxy = _zeroExProxy;
        performanceFeeCollector = _performanceFeeCollector;

        // Set approvals for compounding
        {
            uint256 maxAllowance = type(uint256).max;
            if (_vaultType == IMorigamiGmxEarnAccount.VaultType.GLP) {
                address oGlpAddr = address(gmxManager.oGlpToken());
                wrappedNativeToken.safeIncreaseAllowance(oGlpAddr, maxAllowance);
                gmxManager.gmxToken().safeIncreaseAllowance(zeroExProxy, maxAllowance);
                IERC20(oGlpAddr).safeIncreaseAllowance(address(ovToken), maxAllowance);
            } else {
                address oGmxAddr = address(gmxManager.oGmxToken());
                wrappedNativeToken.safeIncreaseAllowance(zeroExProxy, maxAllowance);
                gmxManager.gmxToken().safeIncreaseAllowance(oGmxAddr, maxAllowance);
                IERC20(oGmxAddr).safeIncreaseAllowance(address(ovToken), maxAllowance);
            }           
        }
    }
    
    /// @notice Set the Morigami GMX Manager contract used to apply GMX to earn rewards.
    function setMorigamiGmxManagers(
        IMorigamiGmxEarnAccount.VaultType _vaultType, 
        address _gmxManager, 
        address _glpManager
    ) external onlyElevatedAccess {
        emit MorigamiGmxManagersSet(_vaultType, _gmxManager, _glpManager);
        vaultType = _vaultType;
        gmxManager = IMorigamiGmxManager(_gmxManager);
        glpManager = IMorigamiGmxManager(_glpManager);
    }

    /// @notice Set the address for where Morigami performance fees are sent
    function setPerformanceFeeCollector(address _performanceFeeCollector) external onlyElevatedAccess {
        emit PerformanceFeeCollectorSet(_performanceFeeCollector);
        performanceFeeCollector = _performanceFeeCollector;
    }

    /// @notice The set of reward tokens we give to the staking contract.
    /// @dev Part of the IMorigamiInvestmentManager interface
    function rewardTokensList() external view override returns (address[] memory tokens) {
        return rewardTokens;
    }

    /// @notice The amount of rewards up to this block that Morigami is due to harvest ready for compounding
    /// ie the net amount after Morigami has deducted it's fees.
    /// Performance fees are not deducted from these amounts.
    function harvestableRewards() external override view returns (uint256[] memory amounts) {
        // Pull the GLP manager rewards - for both GMX and GLP vaults
        amounts = glpManager.harvestableRewards(vaultType);
        uint256 _length = rewardTokens.length;

        // Pull the GMX manager rewards - only relevant for the GMX vault
        uint256 i;
        if (vaultType == IMorigamiGmxEarnAccount.VaultType.GMX) {
            uint256[] memory _gmxAmounts = gmxManager.harvestableRewards(vaultType);
            for (; i < _length; ++i) {
                amounts[i] += _gmxAmounts[i];
            }
        }

        // And also add in any not-yet-distributed harvested amounts (ie if gmxManager.harvestRewards() was called directly),
        // and sitting in this aggregator, but not yet converted & compounded
        for (i=0; i < _length; ++i) {
            amounts[i] += IERC20(rewardTokens[i]).balanceOf(address(this));
        }
    }

    /// @notice The current native token and oGMX reward rates per second
    /// @dev Based on the current total Morigami rewards, minus any portion of performance fees which Morigami receives
    /// will take.
    function projectedRewardRates(bool subtractPerformanceFees) external view override returns (uint256[] memory amounts) {
        // Pull the GLP manager rewards - for both GMX and GLP vaults
        amounts = glpManager.projectedRewardRates(vaultType);
        uint256 _length = rewardTokens.length;

        // Pull the GMX manager rewards - only relevant for the GMX vault
        uint256 i;
        if (vaultType == IMorigamiGmxEarnAccount.VaultType.GMX) {
            uint256[] memory _gmxAmounts = gmxManager.projectedRewardRates(vaultType);
            for (; i < _length; ++i) {
                amounts[i] += _gmxAmounts[i];
            }
        }

        // Remove any performance fees as users aren't due these.
        if (subtractPerformanceFees) {
            uint256 feeRate = ovToken.performanceFee();
            for (i=0; i < _length; ++i) {
                amounts[i] = amounts[i].subtractBps(feeRate, MorigamiMath.Rounding.ROUND_DOWN);
            }
        } 
    }

    /**
     * @notice Harvest any Morigami claimable rewards from the glpManager and gmxManager, and auto-compound
     * by converting rewards into the oToken and adding as reserves of the ovToken.
     * @dev The amount of oToken actually added as new reserves may less than the total balance held by this address,
     * in order to smooth out lumpy yield.
     * Performance fees are deducted from the amount to actually add to reserves.
     */
    function harvestRewards(bytes calldata harvestParams) external override onlyElevatedAccess {
        lastHarvestedAt = block.timestamp;

        // Pull the GLP manager rewards - for both GMX and GLP vaults
        glpManager.harvestRewards();

        // The GLP vault doesn't need to harvest from the GMX vault - it won't have any rewards.
        if (vaultType == IMorigamiGmxEarnAccount.VaultType.GMX) {
            gmxManager.harvestRewards();
            _compoundOvGmxRewards(harvestParams);
        } else {
            _compoundOvGlpRewards(harvestParams);
        }
    }

    function _compoundOvGmxRewards(bytes calldata harvestParams) internal {
        HarvestGmxParams memory params = abi.decode(harvestParams, (HarvestGmxParams));
        emit CompoundOvGmx(params);
        uint256 _length = rewardTokens.length;

        for (uint256 i; i < _length; ++i) {
            // Swap native Token to GMX
            if (rewardTokens[i] == address(wrappedNativeToken)) {
                _swapAssetToAsset0x(params.nativeToGmxSwapData);
            }
        }

        // Swap GMX -> oGMX
        IMorigamiInvestment oGmx = IMorigamiInvestment(address(gmxManager.oGmxToken()));
        oGmx.investWithToken(params.oGmxInvestQuoteData);

        // Add a percentage of all available oGMX reserves, taking a performance fee.
        uint256 reserveTokenBalance = oGmx.balanceOf(address(this));
        _addReserves(address(oGmx), reserveTokenBalance * params.addToReserveAmountPct / 10_000);
    }

    function _compoundOvGlpRewards(bytes calldata harvestParams) internal {
        HarvestGlpParams memory params = abi.decode(harvestParams, (HarvestGlpParams));
        emit CompoundOvGlp(params);
        uint256 _length = rewardTokens.length;

        address oGmxAddr = address(gmxManager.oGmxToken());
        IMorigamiInvestment oGmx = IMorigamiInvestment(oGmxAddr);
        
        for (uint256 i; i < _length; ++i) {
            if (rewardTokens[i] == oGmxAddr) {
                // Swap oGMX -> GMX 
                oGmx.exitToToken(params.oGmxExitQuoteData, address(this));

                // Swap GMX -> wrappedNativeToken
                _swapAssetToAsset0x(params.gmxToNativeSwapData);
            }
        }

        // Swap wrappedNativeToken -> oGLP
        IMorigamiInvestment oGlp = IMorigamiInvestment(address(glpManager.oGlpToken()));
        oGlp.investWithToken(params.oGlpInvestQuoteData);

        // Add a percentage of all available oGLP reserves, taking a performance fee.
        uint256 reserveTokenBalance = oGlp.balanceOf(address(this));
        _addReserves(address(oGlp), reserveTokenBalance * params.addToReserveAmountPct / 10_000);
    }

    function _addReserves(address reserveToken, uint256 totalReservesAmount) internal {
        // Collect performance fees
        uint256 feeRate = ovToken.performanceFee();
        (uint256 reserves, uint256 fees) = totalReservesAmount.splitSubtractBps(feeRate, MorigamiMath.Rounding.ROUND_DOWN);
        
        if (fees != 0) {
            emit PerformanceFeesCollected(reserveToken, fees, performanceFeeCollector);
            IERC20(reserveToken).safeTransfer(performanceFeeCollector, fees);
        }

        // Add the oGMX as reserves into ovToken
        if (reserves != 0) {
            ovToken.addPendingReserves(reserves);
        }
    }

    /// @notice Use external aggregators 0x to contract the swap transaction
    function _swapAssetToAsset0x(bytes memory swapData) internal {
        (bool success, bytes memory returndata) = zeroExProxy.call(swapData);
        
        if (!success) {
            if (returndata.length != 0) {
                // Look for revert reason and bubble it up if present
                // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L232
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            }
            revert UnknownSwapError(returndata);
        }
    }

    /// @notice Owner can recover tokens
    function recoverToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyElevatedAccess {
        // Can't recover any of the reward tokens or transient conversion tokens.
        if (_token == address(wrappedNativeToken)) revert CommonEventsAndErrors.InvalidToken(_token);
        if (_token == address(gmxManager.gmxToken())) revert CommonEventsAndErrors.InvalidToken(_token);
        if (_token == address(gmxManager.oGmxToken())) revert CommonEventsAndErrors.InvalidToken(_token);
        if (_token == address(gmxManager.oGlpToken())) revert CommonEventsAndErrors.InvalidToken(_token);

        emit CommonEventsAndErrors.TokenRecovered(_to, _token, _amount);
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
