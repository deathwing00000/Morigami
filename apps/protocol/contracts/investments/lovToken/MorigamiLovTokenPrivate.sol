pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/lovToken/MorigamiLovToken.sol)

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IMorigamiOTokenManager} from "contracts/interfaces/investments/IMorigamiOTokenManager.sol";
import {IMorigamiLovTokenPrivate} from "contracts/interfaces/investments/lovToken/IMorigamiLovTokenPrivate.sol";
import {IMorigamiLovTokenManager} from "contracts/interfaces/investments/lovToken/managers/IMorigamiLovTokenManager.sol";
import {ITokenPrices} from "contracts/interfaces/common/ITokenPrices.sol";
import {IMorigamiOracle} from "contracts/interfaces/common/oracle/IMorigamiOracle.sol";

import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {MorigamiInvestment} from "contracts/investments/MorigamiInvestment.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";

/**
 * @title Morigami lovToken
 *
 * @notice Only users that has elevated access should be able to deposit with an accepted token
 * It is expected that deposits will be by the owner of the lovToken which will be deployed permissionlessly
 * Also deposits can be enabled for some of third party smart contracts More Vaults e.g.
 * In this case, this lov token just the utility to perform leverage yield strategies with comprehensive risk management
 * Since only owner or SC under owner control can deposit, fee should be 0
 * Admin will rebalance to lever up on the underlying reserve token, targetting a
 * specific A/L (assets / liabilities) range
 *
 * @dev The logic on how to handle the specific deposits/exits for each lovToken is delegated
 * to a manager contract
 */
contract MorigamiLovTokenPrivate is
    IMorigamiLovTokenPrivate,
    MorigamiInvestment
{
    using SafeERC20 for IERC20;

    /**
     * @notice The Morigami contract managing the deposits/exits and the application of
     * the deposit tokens into the underlying protocol
     */
    IMorigamiLovTokenManager internal lovManager;

    /**
     * @notice The helper contract to retrieve Morigami USD prices
     * @dev Required for off-chain/subgraph integration
     */
    ITokenPrices public override tokenPrices;

    /**
     * @notice The maximum allowed supply of this token for user investments
     * @dev The actual totalSupply() may be greater than `maxTotalSupply`
     * in order to start organically shrinking supply or from performance fees
     */
    uint256 public override maxTotalSupply;

    constructor(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        address _tokenPrices,
        uint256 _maxTotalSupply
    ) MorigamiInvestment(_name, _symbol, _initialOwner) {
        tokenPrices = ITokenPrices(_tokenPrices);
        maxTotalSupply = _maxTotalSupply;
    }

    /**
     * @notice Set the Morigami lovToken Manager.
     */
    function setManager(address _manager) external override onlyElevatedAccess {
        if (_manager == address(0))
            revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit ManagerSet(_manager);
        lovManager = IMorigamiLovTokenManager(_manager);
    }

    /**
     * @notice Set the max total supply allowed for investments into this lovToken
     */
    function setMaxTotalSupply(
        uint256 _maxTotalSupply
    ) external onlyElevatedAccess {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupplySet(_maxTotalSupply);
    }

    /**
     * @notice Set the helper to calculate current off-chain/subgraph integration
     */
    function setTokenPrices(
        address _tokenPrices
    ) external override onlyElevatedAccess {
        if (_tokenPrices == address(0))
            revert CommonEventsAndErrors.InvalidAddress(address(0));
        emit TokenPricesSet(_tokenPrices);
        tokenPrices = ITokenPrices(_tokenPrices);
    }

    /**
     * @notice User buys this lovToken with an amount of one of the approved ERC20 tokens
     * @param quoteData The quote data received from investQuote()
     * @return investmentAmount The actual number of receipt tokens received, inclusive of any fees.
     */
    function investWithToken(
        InvestQuoteData calldata quoteData
    )
        external
        virtual
        override
        onlyElevatedAccess
        nonReentrant
        returns (uint256 investmentAmount)
    {
        if (quoteData.fromTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();

        // Send the investment token to the manager
        IMorigamiLovTokenManager _manager = lovManager;
        IERC20(quoteData.fromToken).safeTransferFrom(
            msg.sender,
            address(_manager),
            quoteData.fromTokenAmount
        );
        investmentAmount = _manager.investWithToken(msg.sender, quoteData);

        emit Invested(
            msg.sender,
            quoteData.fromTokenAmount,
            quoteData.fromToken,
            investmentAmount
        );

        // Mint the lovToken for the user
        if (investmentAmount != 0) {
            _mint(msg.sender, investmentAmount);
            if (totalSupply() > maxTotalSupply) {
                revert CommonEventsAndErrors.BreachedMaxTotalSupply(
                    totalSupply(),
                    maxTotalSupply
                );
            }
        }
    }

    /**
     * @notice Sell this lovToken to receive one of the accepted exit tokens.
     * @param quoteData The quote data received from exitQuote()
     * @param recipient The receiving address of the `toToken`
     * @return toTokenAmount The number of `toToken` tokens received upon selling the lovToken.
     */
    function exitToToken(
        ExitQuoteData calldata quoteData,
        address recipient
    )
        external
        virtual
        override
        onlyElevatedAccess
        nonReentrant
        returns (uint256 toTokenAmount)
    {
        if (quoteData.investmentTokenAmount == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();
        if (recipient == address(0))
            revert CommonEventsAndErrors.InvalidAddress(recipient);

        uint256 lovTokenToBurn;
        (toTokenAmount, lovTokenToBurn) = lovManager.exitToToken(
            msg.sender,
            quoteData,
            recipient
        );

        emit Exited(
            msg.sender,
            quoteData.investmentTokenAmount,
            quoteData.toToken,
            toTokenAmount,
            recipient
        );

        // Burn the lovToken
        if (lovTokenToBurn != 0) {
            _burn(msg.sender, lovTokenToBurn);
        }
    }

    /**
     * @notice Unsupported - cannot invest in this lovToken to the native chain asset (eg ETH)
     * @dev In future, if required, a separate version which does support this flow will be added
     */
    function investWithNative(
        InvestQuoteData calldata /*quoteData*/
    ) external payable virtual override onlyElevatedAccess returns (uint256) {
        revert Unsupported();
    }

    /**
     * @notice Unsupported - cannot exit this lovToken to the native chain asset (eg ETH)
     * @dev In future, if required, a separate version which does support this flow will be added
     */
    function exitToNative(
        ExitQuoteData calldata /*quoteData*/,
        address payable /*recipient*/
    )
        external
        virtual
        override
        onlyElevatedAccess
        returns (uint256 /*nativeAmount*/)
    {
        revert Unsupported();
    }

    /**
     * @notice The Morigami contract managing the deposits/exits and the application of
     * the deposit tokens into the underlying protocol
     */
    function manager() external view returns (IMorigamiOTokenManager) {
        return IMorigamiOTokenManager(address(lovManager));
    }

    /**
     * @notice The token used to track reserves for this investment
     */
    function reserveToken() external view returns (address) {
        return lovManager.reserveToken();
    }

    /**
     * @notice The underlying reserve token this investment wraps.
     */
    function baseToken() external view virtual override returns (address) {
        return address(lovManager.baseToken());
    }

    /**
     * @notice The set of accepted tokens which can be used to deposit.
     */
    function acceptedInvestTokens()
        external
        view
        virtual
        override
        returns (address[] memory)
    {
        return lovManager.acceptedInvestTokens();
    }

    /**
     * @notice The set of accepted tokens which can be used to exit into.
     */
    function acceptedExitTokens()
        external
        view
        virtual
        override
        returns (address[] memory)
    {
        return lovManager.acceptedExitTokens();
    }

    /**
     * @notice Whether new investments are paused.
     */
    function areInvestmentsPaused()
        external
        view
        virtual
        override
        returns (bool)
    {
        return lovManager.areInvestmentsPaused();
    }

    /**
     * @notice Whether exits are temporarily paused.
     */
    function areExitsPaused() external view virtual override returns (bool) {
        return lovManager.areExitsPaused();
    }

    /**
     * @notice Get a quote to buy the lovToken using an accepted deposit token.
     * @param fromTokenAmount How much of the deposit token to invest with
     * @param fromToken What ERC20 token to purchase with. This must be one of `acceptedInvestTokens`
     * @param maxSlippageBps The maximum acceptable slippage of the received investment amount
     * @param deadline The maximum deadline to execute the exit.
     * @return quoteData The quote data, including any params required for the underlying investment type.
     * @return investFeeBps Any fees expected when investing with the given token, either from Morigami or from the underlying investment.
     */
    function investQuote(
        uint256 fromTokenAmount,
        address fromToken,
        uint256 maxSlippageBps,
        uint256 deadline
    )
        external
        view
        virtual
        override
        returns (
            InvestQuoteData memory quoteData,
            uint256[] memory investFeeBps
        )
    {
        (quoteData, investFeeBps) = lovManager.investQuote(
            fromTokenAmount,
            fromToken,
            maxSlippageBps,
            deadline
        );
    }

    /**
     * @notice Get a quote to sell this lovToken to receive one of the accepted exit tokens
     * @param investmentTokenAmount The amount of this lovToken to sell
     * @param toToken The token to receive when selling. This must be one of `acceptedExitTokens`
     * @param maxSlippageBps The maximum acceptable slippage of the received `toToken`
     * @param deadline The maximum deadline to execute the exit.
     * @return quoteData The quote data, including any other quote params required for this investment type.
     * @return exitFeeBps Any fees expected when exiting the investment to the nominated token, either from Morigami or from the underlying investment.
     */
    function exitQuote(
        uint256 investmentTokenAmount,
        address toToken,
        uint256 maxSlippageBps,
        uint256 deadline
    )
        external
        view
        virtual
        override
        returns (ExitQuoteData memory quoteData, uint256[] memory exitFeeBps)
    {
        (quoteData, exitFeeBps) = lovManager.exitQuote(
            investmentTokenAmount,
            toToken,
            maxSlippageBps,
            deadline
        );
    }

    /**
     * @notice How many reserve tokens would one get given a number of lovToken shares
     * @dev This will use the `SPOT_PRICE` to value any debt in terms of the reserve token
     */
    function sharesToReserves(
        uint256 shares
    ) external view override returns (uint256) {
        return
            lovManager.sharesToReserves(
                shares,
                IMorigamiOracle.PriceType.SPOT_PRICE
            );
    }

    /**
     * @notice How many lovToken shares would one get given a number of reserve tokens
     * @dev This will use the Oracle `SPOT_PRICE` to value any debt in terms of the reserve token
     */
    function reservesToShares(
        uint256 reserves
    ) external view override returns (uint256) {
        return
            lovManager.reservesToShares(
                reserves,
                IMorigamiOracle.PriceType.SPOT_PRICE
            );
    }

    /**
     * @notice How many reserve tokens would one get given a single share, as of now
     * @dev This will use the Oracle 'HISTORIC_PRICE' to value any debt in terms of the reserve token
     */
    function reservesPerShare() external view override returns (uint256) {
        return
            lovManager.sharesToReserves(
                10 ** decimals(),
                IMorigamiOracle.PriceType.HISTORIC_PRICE
            );
    }

    /**
     * @notice The current amount of available reserves for redemptions
     * @dev This will use the Oracle `SPOT_PRICE` to value any debt in terms of the reserve token
     */
    function totalReserves() external view override returns (uint256) {
        return
            lovManager.userRedeemableReserves(
                IMorigamiOracle.PriceType.SPOT_PRICE
            );
    }

    /**
     * @notice Retrieve the current assets, liabilities and calculate the ratio
     * @dev This will use the Oracle `SPOT_PRICE` to value any debt in terms of the reserve token
     */
    function assetsAndLiabilities()
        external
        view
        override
        returns (uint256 /*assets*/, uint256 /*liabilities*/, uint256 /*ratio*/)
    {
        return
            lovManager.assetsAndLiabilities(
                IMorigamiOracle.PriceType.SPOT_PRICE
            );
    }

    /**
     * @notice The current effective exposure (EE) of this lovToken
     * to `PRECISION` precision
     * @dev = reserves / (reserves - liabilities)
     * This will use the Oracle `SPOT_PRICE` to value any debt in terms of the reserve token
     */
    function effectiveExposure()
        external
        view
        override
        returns (uint128 /*effectiveExposure*/)
    {
        return
            lovManager.effectiveExposure(IMorigamiOracle.PriceType.SPOT_PRICE);
    }

    /**
     * @notice The valid lower and upper bounds of A/L allowed when users deposit/exit into lovToken
     * @dev Transactions will revert if the resulting A/L is outside of this range
     */
    function userALRange()
        external
        view
        override
        returns (uint128 /*floor*/, uint128 /*ceiling*/)
    {
        return lovManager.userALRange();
    }

    /**
     * @notice The current deposit and exit fee based on market conditions.
     * Fees are the equivalent of burning lovToken shares - benefit remaining vault users
     * @dev represented in basis points, in MorigamiLovTokenV2, dynamic fees should be 0
     */
    function getDynamicFeesBps()
        external
        view
        override
        returns (uint256 depositFeeBps, uint256 exitFeeBps)
    {
        return lovManager.getDynamicFeesBps();
    }

    /**
     * @notice The maximum amount of fromToken's that can be deposited
     * taking any other underlying protocol constraints into consideration
     */
    function maxInvest(
        address fromToken
    ) external view override returns (uint256) {
        return lovManager.maxInvest(fromToken);
    }

    /**
     * @notice The maximum amount of tokens that can be exited into the toToken
     * taking any other underlying protocol constraints into consideration
     */
    function maxExit(address toToken) external view override returns (uint256) {
        return lovManager.maxExit(toToken);
    }
}
