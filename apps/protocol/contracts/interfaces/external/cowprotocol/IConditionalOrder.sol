pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

// @note Forked from https://github.com/cowprotocol/composable-cow/blob/24d556b634e21065e0ee70dd27469a6e699a8998/src/interfaces/IConditionalOrder.sol#L12

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IWatchtowerErrors } from "contracts/interfaces/external/cowprotocol/IWatchtowerErrors.sol";
import { GPv2Order } from "contracts/external/cowprotocol/GPv2Order.sol";

interface IConditionalOrder is IERC165, IERC1271, IWatchtowerErrors {
    /**
     * @dev This event is emitted when a new conditional order needs to be created.
     * @param owner the address that has created the conditional order
     * @param params the address / salt / data of the conditional order
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/ComposableCoW.sol#L51-L52
     */
    event ConditionalOrderCreated(address indexed owner, ConditionalOrderParams params);

    /**
     * @notice Parameters to identify a conditional order, generated by an owner.
     * Concurrent conditional orders by the same owner must have a unique hash:
     *   H(handler || salt || staticInput)
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/interfaces/IConditionalOrder.sol#L32
     */
    struct ConditionalOrderParams {
        address handler;
        bytes32 salt;
        bytes staticInput;
    }

    /**
     * @notice The watchtower off-chain service calls this to automatically create discrete orders and
     * post them on the orderbook. It outputs an order for the parameters together with a valid signature.
     * @dev Some parameters in this interface are unused as they refer to features of ComposableCoW which
     * aren't required when implementing directly.
     * @param owner of the order.
     * @param params `ConditionalOrderParams` for the order
     * @param offchainInput any dynamic off-chain input for generating the discrete order. As of writing, watchtower sets as bytes("")
     * @param proof if using merkle-roots that H(handler || salt || staticInput) is in the merkle tree
     * @return order discrete order for submitting to CoW Protocol API
     * @return signature for submitting to CoW Protocol API
     *
     * https://github.com/cowprotocol/composable-cow/blob/2ba71df3d5fdbfe8b92a540837262e164a0290ab/src/ComposableCoW.sol#L221
     */
    function getTradeableOrderWithSignature(
        address owner,
        IConditionalOrder.ConditionalOrderParams calldata params,
        bytes calldata offchainInput,
        bytes32[] calldata proof
    ) external view returns (
        GPv2Order.Data memory order, 
        bytes memory signature
    );
}