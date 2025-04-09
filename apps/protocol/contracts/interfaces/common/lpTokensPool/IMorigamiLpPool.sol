pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Origami (interfaces/common/lpTokensPool/IMorigamiLpPool.sol)

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @notice An on chain lp token pool, to integrate with the Curve, Uniswap,
 * possibly others which obtain quote calldata offchain and then execute via a low level call
 * to perform the lp mint/burn onchain
 */
interface IMorigamiLpPool {
    error InvalidRouter(address router);

    event LpMinted(address indexed lpToken, uint256 amountMinted);
    event LpBurnt(address indexed lpToken, uint256 amountBurnt);
    event RouterWhitelisted(address indexed router, bool allowed);

    enum Action {
        Add,
        Remove
    }

    /**
     * @notice Pull tokens from sender then execute the lp mint or burn
     */
    function execute(
        IERC20 lpToken,
        IERC20[] memory tokensInPool,
        uint256[] memory amounts,
        uint256 amountLpTokenDesired,
        Action actionType,
        bytes calldata lpPoolData
    ) external;
}
