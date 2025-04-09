pragma solidity 0.8.19;
// SPDX-License-Identifier: AGPL-3.0-or-later

import { IMorigamiInvestment } from "contracts/interfaces/investments/IMorigamiInvestment.sol";

contract DummyProtocolWrapper {
    function investWithToken(
        IMorigamiInvestment investment,
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external returns (uint256) {
        return investment.investWithToken(quoteData);
    }

    function investWithNative(
        IMorigamiInvestment investment,
        IMorigamiInvestment.InvestQuoteData calldata quoteData
    ) external payable returns (uint256) {
        return investment.investWithNative{value: msg.value}(quoteData);
    }
}
