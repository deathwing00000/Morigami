pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later
// Morigami (investments/MorigamiInvestment.sol)

import { IMorigamiInvestment } from "contracts/interfaces/investments/IMorigamiInvestment.sol";
import { MintableToken } from "contracts/common/MintableToken.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Morigami Investment
 * @notice Users invest in the underlying protocol and receive a number of this Morigami investment in return.
 * Morigami will apply the accepted investment token into the underlying protocol in the most optimal way.
 */
abstract contract MorigamiInvestment is IMorigamiInvestment, MintableToken, ReentrancyGuard {
    string public constant API_VERSION = "0.2.0";
    
    /**
     * @notice Track the depoyed version of this contract. 
     */
    function apiVersion() external override pure returns (string memory) {
        return API_VERSION;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _initialOwner
    ) MintableToken(_name, _symbol, _initialOwner) {
    }
}
