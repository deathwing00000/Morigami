pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (interfaces/common/IWrappedToken.sol)

interface IWrappedToken {
    function deposit() external payable;
    function withdraw(uint256) external;
}