pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/staking/IMorigamiInvestmentManager.sol)

interface IMorigamiInvestmentManager {
    event PerformanceFeesCollected(address indexed token, uint256 amount, address indexed feeCollector);

    function rewardTokensList() external view returns (address[] memory tokens);
    function harvestRewards(bytes calldata harvestParams) external;
    function harvestableRewards() external view returns (uint256[] memory amounts);
    function projectedRewardRates(bool subtractPerformanceFees) external view returns (uint256[] memory amounts);
}
