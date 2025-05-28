pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/oracle/MorigamiCurveLpTokenOracle.sol)

import {MorigamiOracleBase} from "contracts/common/oracle/MorigamiOracleBase.sol";
import {MorigamiMath} from "contracts/libraries/MorigamiMath.sol";
import {ICurvePool} from "contracts/interfaces/external/curve/ICurvePool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IAggregatorV3Interface} from "../../interfaces/external/chainlink/IAggregatorV3Interface.sol";

/**
 * @title MorigamiCurveLpTokenOracle
 * @notice The oracle price is calculated based on the price of the quote token in the CurvePool
 * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
 */
contract MorigamiCurveLpTokenOracle is MorigamiOracleBase {
    ICurvePool public immutable curvePool;

    // index of the quote token in the CurvePool
    int128 public immutable qouteTokenIndex;

    address public immutable quoteAssetOracleAddress;

    constructor(
        BaseOracleParams memory baseParams,
        int128 _qouteTokenIndex,
        address _curvePool,
        address _quoteAssetOracleAddress
    ) MorigamiOracleBase(baseParams) {
        qouteTokenIndex = _qouteTokenIndex;
        curvePool = ICurvePool(_curvePool);
        quoteAssetOracleAddress = _quoteAssetOracleAddress;
    }

    /**
     * @notice Return the current conversion rate a.k.a price for 1 lpToken in quoteAsset
     * @dev The price is calculated as the amount of quoteAsset that would be received for 1 lpToken(baseAsset)
     */
    function latestPrice(
        PriceType,
        MorigamiMath.Rounding
    ) public view override returns (uint256 price) {
        // should take into account decimals difference between baseAsset and quoteAsset
        price = curvePool.calc_withdraw_one_coin(
            1 * 10 ** (IERC20Metadata(baseAsset).decimals()),
            qouteTokenIndex
        );

        price =
            (price * 10 ** decimals) /
            10 ** (IERC20Metadata(quoteAsset).decimals());
    }
}
