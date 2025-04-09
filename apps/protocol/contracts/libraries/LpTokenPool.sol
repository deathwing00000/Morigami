pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (libraries/LpTokenPool.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";

/**
 * @notice Execute a add liquidity or remove liquidity on a LP Token Pool
 */
library LpTokenPool {
    using SafeERC20 for IERC20;

    error UnknownAddLiquidityError(bytes result);
    error InvalidAddLiquidity();
    error InvalidRemoveLiquidity();

    function addLiquidity(
        address router,
        IERC20 lpToken,
        IERC20[] memory tokensInPool,
        uint256[] memory amounts,
        uint256 amountLpTokenDesired,
        bytes memory addLiquidityData
    ) internal returns (uint256 lpTokenAmount) {
        if (amountLpTokenDesired == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();

        uint256 _initialLpTokenBalance = lpToken.balanceOf(address(this));

        // Approve the router to pull the sellToken's
        for (uint256 i = 0; i < tokensInPool.length; i++) {
            tokensInPool[i].forceApprove(router, amounts[i]);
        }

        // Execute via a low-level call on the dex aggregator router.
        (bool _success, bytes memory _returndata) = router.call(
            addLiquidityData
        );
        if (!_success) {
            if (_returndata.length != 0) {
                // Look for revert reason and bubble it up if present
                // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L232
                assembly {
                    let returndata_size := mload(_returndata)
                    revert(add(32, _returndata), returndata_size)
                }
            }
            revert UnknownAddLiquidityError(_returndata);
        }

        lpTokenAmount =
            lpToken.balanceOf(address(this)) -
            _initialLpTokenBalance;

        if (lpTokenAmount < amountLpTokenDesired) revert InvalidAddLiquidity();
    }

    function removeLiquidity(
        address router,
        IERC20 lpToken,
        IERC20[] memory tokensInPool,
        uint256[] memory amountsOutMin,
        uint256 amountLpTokenToBurn,
        bytes memory removeLiquidityData
    ) internal {
        if (amountLpTokenToBurn == 0)
            revert CommonEventsAndErrors.ExpectedNonZero();

        uint256[] memory _initialBalances = new uint256[](tokensInPool.length);
        for (uint256 i = 0; i < tokensInPool.length; ) {
            _initialBalances[i] = tokensInPool[i].balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        // Approve the router to pull the sellToken's
        lpToken.forceApprove(router, amountLpTokenToBurn);

        // Execute via a low-level call on the dex aggregator router.
        (bool _success, bytes memory _returndata) = router.call(
            removeLiquidityData
        );
        if (!_success) {
            if (_returndata.length != 0) {
                // Look for revert reason and bubble it up if present
                // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L232
                assembly {
                    let returndata_size := mload(_returndata)
                    revert(add(32, _returndata), returndata_size)
                }
            }
            revert UnknownAddLiquidityError(_returndata);
        }

        for (uint256 i = 0; i < tokensInPool.length; ) {
            if (
                tokensInPool[i].balanceOf(address(this)) - _initialBalances[i] <
                amountsOutMin[i]
            ) {
                revert InvalidRemoveLiquidity();
            }
            unchecked {
                ++i;
            }
        }
    }
}
