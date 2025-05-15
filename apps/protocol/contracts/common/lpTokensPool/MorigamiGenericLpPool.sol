pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (common/lpTokensPool/MorigamiGenericLpPool.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IMorigamiLpPool} from "contracts/interfaces/common/lpTokensPool/IMorigamiLpPool.sol";
import {MorigamiElevatedAccess} from "contracts/common/access/MorigamiElevatedAccess.sol";
import {CommonEventsAndErrors} from "contracts/libraries/CommonEventsAndErrors.sol";
import {LpTokenPool} from "contracts/libraries/LpTokenPool.sol";

/**
 * @notice An on chain swapper contract to integrate with the 1Inch router | 0x proxy,
 * possibly others which obtain quote calldata offchain and then execute via a low level call
 * to perform the swap onchain.
 * @dev The amount of tokens bought is expected to be checked for slippage in the calling contract
 */
contract MorigamiGenericLpPool is IMorigamiLpPool, MorigamiElevatedAccess {
    using SafeERC20 for IERC20;
    using LpTokenPool for address;

    struct RouteData {
        address router;
        bytes data;
    }

    /// @notice Approved router contracts for swaps
    mapping(address router => bool allowed) public whitelistedRouters;

    constructor(address _initialOwner) MorigamiElevatedAccess(_initialOwner) {}

    function whitelistRouter(
        address router,
        bool allowed
    ) external onlyElevatedAccess {
        whitelistedRouters[router] = allowed;
        emit RouterWhitelisted(router, allowed);
    }

    /**
     * @notice Recover any token -- this contract should not ordinarily hold any tokens.
     * @param token Token to recover
     * @param to Recipient address
     * @param amount Amount to recover
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyElevatedAccess {
        emit CommonEventsAndErrors.TokenRecovered(to, token, amount);
        IERC20(token).safeTransfer(to, amount);
    }

    function execute(
        IERC20 lpToken,
        IERC20[] memory tokensInPool,
        uint256[] memory amounts,
        uint256 amountLpTokenDesired,
        Action actionType, // add is true, remove is false
        bytes calldata lpPoolData
    ) external override {
        RouteData memory routeData = abi.decode(lpPoolData, (RouteData));
        if (!whitelistedRouters[routeData.router])
            revert InvalidRouter(routeData.router);

        uint256[] memory balancesBefore = new uint256[](tokensInPool.length);
        for (uint256 i = 0; i < tokensInPool.length; ) {
            balancesBefore[i] = tokensInPool[i].balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        if (actionType == Action.Add) {
            for (uint256 i = 0; i < tokensInPool.length; i++) {
                tokensInPool[i].safeTransferFrom(
                    msg.sender,
                    address(this),
                    amounts[i]
                );
            }

            routeData.router.addLiquidity(
                lpToken,
                tokensInPool,
                amounts,
                amountLpTokenDesired,
                routeData.data
            );

            // Transfer back to the caller
            lpToken.safeTransfer(msg.sender, amountLpTokenDesired);

            for (uint256 i = 0; i < amounts.length; ) {
                tokensInPool[i].safeTransfer(
                    msg.sender,
                    tokensInPool[i].balanceOf(address(this)) - balancesBefore[i]
                );
                unchecked {
                    ++i;
                }
            }
        } else {
            lpToken.safeTransferFrom(
                msg.sender,
                address(this),
                amountLpTokenDesired
            );

            routeData.router.removeLiquidity(
                lpToken,
                tokensInPool,
                amounts,
                amountLpTokenDesired,
                routeData.data
            );

            // Transfer back to the caller
            for (uint256 i = 0; i < amounts.length; ) {
                tokensInPool[i].safeTransfer(
                    msg.sender,
                    tokensInPool[i].balanceOf(address(this)) - balancesBefore[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
    }
}
