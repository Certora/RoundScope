// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {StakedToken } from "@tokens/StakedToken.sol";
import {YieldSharingV2} from "@finance/YieldSharingV2.sol";


contract StakedTokenHarness is StakedToken {

    constructor(address _core, address _receiptToken) 
        StakedToken(_core, _receiptToken) {}

    function thereAreNoUnaccruedLosses() public returns (bool) {
        return YieldSharingV2(yieldSharing).unaccruedYield() >= 0;
    }
}
