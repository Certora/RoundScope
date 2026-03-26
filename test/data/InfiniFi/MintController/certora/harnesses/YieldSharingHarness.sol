// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {YieldSharingV2} from "@finance/YieldSharingV2.sol";

contract YieldSharingV2Harness is YieldSharingV2 {
    constructor(address _core, address _accounting, address _receiptToken, address _stakedToken, address _lockingModule)
        YieldSharingV2(_core, _accounting, _receiptToken, _stakedToken, _lockingModule)
    {}

    function handleNegaiveYield(uint256 _negativeYield) public {
        _handleNegativeYield(_negativeYield);
    }
}
