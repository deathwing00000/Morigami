pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiCurveLpTokenOracle.sol)

import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {ICurvePool} from "contracts/interfaces/external/curve/ICurvePool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAggregatorV3Interface} from "contracts/interfaces/external/chainlink/IAggregatorV3Interface.sol";

/**
 * @title MorigamiCurveLpTokenOracle
 * @notice The oracle price is calculated based on the price of the quote token in the CurvePool
 * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
 */
contract MorigamiCurveLpTokenOracle is MorigamiOracleBase {
    using MorigamiMath for uint256;

    error ArgumentLengthMismatch();
    error QuoteAssetInvalidIndex();
    error TokensIndicesMismatch(address, address);
    error ProvidedTokensNotInThePool();

    ICurvePool public immutable curvePool;
    // tokens other than base and quote assets
    address[] private tokens;
    // oracles converting tokens into quote assets
    mapping(address => address) public oracles;

    constructor(
        BaseOracleParams memory baseParams,
        address _curvePool,
        address[] memory _tokens,
        address[] memory _oracles
    ) MorigamiOracleBase(baseParams) {
        if (_tokens.length != _oracles.length) {
            revert ArgumentLengthMismatch();
        }

        if (_tokens[0] != baseParams.quoteAssetAddress) {
            revert QuoteAssetInvalidIndex();
        }

        _verifyAndSave(_curvePool, _tokens, _oracles);

        curvePool = ICurvePool(_curvePool);
    }

    /**
     * @notice Return the current conversion rate a.k.a price for 1 lpToken in quoteAsset
     * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
     */
    function latestPrice(
        PriceType,
        MorigamiMath.Rounding
    ) public view override returns (uint256 price_) {
        // relative price of LP token with 18 decimals
        uint256 relativePrice = curvePool.get_virtual_price();

        // calculate least valued token price (normalized to 18 decimals)
        uint256 minPrice = type(uint256).max;
        
        for (uint256 i = 0; i < tokens.length;) {
            uint256 price;
            
            if (tokens[i] == quoteAsset) {
                // Quote asset price is 1.0 in 18 decimals
                price = 1e18;
            } else {
                // Get price from oracle and normalize to 18 decimals
                IAggregatorV3Interface oracle = IAggregatorV3Interface(oracles[tokens[i]]);
                uint256 oraclePrice = uint256(oracle.latestAnswer());
                uint8 oracleDecimals = oracle.decimals();
                price = oraclePrice.mulDiv(1e18, (10 ** oracleDecimals), MorigamiMath.Rounding.ROUND_DOWN);
            }
            
            if (price < minPrice) {
                minPrice = price;
            }
            
            unchecked {
                ++i;
            }
        }
        
        // LP token price = virtual_price * min_token_price (both in 18 decimals)
        price_ = relativePrice.mulDiv(minPrice, 1e18, MorigamiMath.Rounding.ROUND_DOWN);
    }

    function convertAmount(
        address fromAsset,
        uint256 fromAssetAmount,
        PriceType,
        MorigamiMath.Rounding
    ) public view override(MorigamiOracleBase) returns (uint256) {
        return fromAsset == baseAsset ?
            _convertFromBaseAsset(fromAssetAmount) :
            _convertToBaseAsset(fromAsset, fromAssetAmount);
    }

    /**
     * @notice Converts LP into quote asset
     */
    function _convertFromBaseAsset(
        uint256 _amount
    ) private view returns (uint256) {
        uint256 price = latestPrice(PriceType.SPOT_PRICE, MorigamiMath.Rounding.ROUND_DOWN);
        uint8 quoteDecimals = IERC20Metadata(quoteAsset).decimals();
        uint8 baseDecimals = IERC20Metadata(baseAsset).decimals();
        
        // return amount of quote asset tokens with normalization to asset natural decimals
        return _amount.mulDiv(
            price * (10 ** quoteDecimals),
            1e18 * (10 ** baseDecimals),
            MorigamiMath.Rounding.ROUND_DOWN
        );
    }

    /**
     * @notice Converts any token from the pool to the LP 
     */
    function _convertToBaseAsset(
        address _fromAsset,
        uint256 _amount
    ) private view returns (uint256) {
        uint8 quoteDecimals = IERC20Metadata(quoteAsset).decimals();
        
        if (_fromAsset != quoteAsset) {
            // Convert _fromAsset amount to quote asset amount
            IAggregatorV3Interface oracle = IAggregatorV3Interface(oracles[_fromAsset]);
            uint256 oraclePrice = uint256(oracle.latestAnswer());
            uint8 oracleDecimals = oracle.decimals();
            uint8 fromDecimals = IERC20Metadata(_fromAsset).decimals();
            
            _amount = _amount.mulDiv(
                oraclePrice * (10 ** quoteDecimals),
                (10 ** fromDecimals) * (10 ** oracleDecimals),
                MorigamiMath.Rounding.ROUND_DOWN
            );
        }
        
        // Now _amount is in quote asset decimals
        // Convert quote asset amount to LP tokens
        uint256 lpPrice = latestPrice(PriceType.SPOT_PRICE, MorigamiMath.Rounding.ROUND_DOWN);
        uint8 baseDecimals = IERC20Metadata(baseAsset).decimals();
        
        //_amount * 1e18 * 10^baseDecimals / (lpPrice * 10^quoteDecimals)
        return _amount.mulDiv(
            1e18 * (10 ** baseDecimals),
            lpPrice * (10 ** quoteDecimals),
            MorigamiMath.Rounding.ROUND_DOWN
        );
    }

    function _verifyAndSave(
        address _curvePool,
        address[] memory _tokens,
        address[] memory _oracles
    ) private {
        uint256 realLength;
        for(uint256 i = 0;;) {
            try ICurvePool(_curvePool).coins(i) returns (address token) {
                if (i < _tokens.length) {
                    _compareAddresses(token, _tokens[i]);
                    oracles[_tokens[i]] = _oracles[i];
                }
                unchecked {
                    ++realLength;
                    ++i;
                }
            } catch (bytes memory) {
                break;
            }
        }
        if (realLength != _tokens.length) revert ProvidedTokensNotInThePool();
        tokens = _tokens;
    }

    function _compareAddresses(address first, address second) private pure {
        if (first != second) revert TokensIndicesMismatch(first, second);
    }
}
