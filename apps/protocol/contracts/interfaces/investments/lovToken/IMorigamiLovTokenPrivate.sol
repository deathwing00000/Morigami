pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/investments/lovToken/IMorigamiLovTokenPrivate.sol)

import {IMorigamiOTokenManager} from "contracts/interfaces/investments/IMorigamiOTokenManager.sol";
import {IMorigamiInvestment} from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import {ITokenPrices} from "contracts/interfaces/common/ITokenPrices.sol";

/**
 * @title Morigami lovToken
 *
 * @notice Users deposit with an accepted token and are minted lovTokens
 * Morigami will rebalance to lever up on the underlying reserve token, targetting a
 * specific A/L (assets / liabilities) range
 *
 * @dev The logic on how to handle the specific deposits/exits for each lovToken is delegated
 * to a manager contract
 */
interface IMorigamiLovTokenPrivate is IMorigamiInvestment {
    event PerformanceFeesCollected(
        address indexed feeCollector,
        uint256 mintAmount
    );
    event FeeCollectorSet(address indexed feeCollector);
    event MaxTotalSupplySet(uint256 maxTotalSupply);

    /**
     * @notice The token used to track reserves for this investment
     */
    function reserveToken() external view returns (address);

    /**
     * @notice The Morigami contract managing the deposits/exits and the application of
     * the deposit tokens into the underlying protocol
     */
    function manager() external view returns (IMorigamiOTokenManager);

    /**
     * @notice Set the Morigami lovToken Manager.
     */
    function setManager(address _manager) external;

    /**
     * @notice Set the max total supply allowed for investments into this lovToken
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external;

    /**
     * @notice Set the helper to calculate current off-chain/subgraph integration
     */
    function setTokenPrices(address _tokenPrices) external;

    /**
     * @notice How many reserve tokens would one get given a number of lovToken shares
     * @dev Implementations must use the Oracle 'SPOT_PRICE' to value any debt in terms of the reserve token
     */
    function sharesToReserves(uint256 shares) external view returns (uint256);

    /**
     * @notice How many lovToken shares would one get given a number of reserve tokens
     * @dev Implementations must use the Oracle 'SPOT_PRICE' to value any debt in terms of the reserve token
     */
    function reservesToShares(uint256 reserves) external view returns (uint256);

    /**
     * @notice How many reserve tokens would one get given a single share, as of now
     * @dev Implementations must use the Oracle 'HISTORIC_PRICE' to value any debt in terms of the reserve token
     */
    function reservesPerShare() external view returns (uint256);

    /**
     * @notice The current amount of available reserves for redemptions
     * @dev Implementations must use the Oracle 'SPOT_PRICE' to value any debt in terms of the reserve token
     */
    function totalReserves() external view returns (uint256);

    /**
     * @notice The maximum allowed supply of this token for user investments
     * @dev The actual totalSupply() may be greater than `maxTotalSupply`
     * in order to start organically shrinking supply or from performance fees
     */
    function maxTotalSupply() external view returns (uint256);

    /**
     * @notice Retrieve the current assets, liabilities and calculate the ratio
     * @dev Implementations must use the Oracle 'SPOT_PRICE' to value any debt in terms of the reserve token
     */
    function assetsAndLiabilities()
        external
        view
        returns (uint256 assets, uint256 liabilities, uint256 ratio);

    /**
     * @notice The current effective exposure (EE) of this lovToken
     * to `PRECISION` precision
     * @dev = reserves / (reserves - liabilities)
     * Implementations must use the Oracle 'SPOT_PRICE' to value any debt in terms of the reserve token
     */
    function effectiveExposure() external view returns (uint128);

    /**
     * @notice The valid lower and upper bounds of A/L allowed when users deposit/exit into lovToken
     * @dev Transactions will revert if the resulting A/L is outside of this range
     */
    function userALRange()
        external
        view
        returns (uint128 floor, uint128 ceiling);

    /**
     * @notice The current deposit and exit fee based on market conditions.
     * Fees are the equivalent of burning lovToken shares - benefit remaining vault users
     * @dev represented in basis points
     */
    function getDynamicFeesBps()
        external
        view
        returns (uint256 depositFeeBps, uint256 exitFeeBps);

    /**
     * @notice The helper contract to retrieve Morigami USD prices
     * @dev Required for off-chain/subgraph integration
     */
    function tokenPrices() external view returns (ITokenPrices);
}
