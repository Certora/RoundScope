// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CoreControlled} from "@core/CoreControlled.sol";

// transparent mock of CoreControlled
// this is used to test CoreControlled because CoreControlled is abstract
contract MockCoreControlled is CoreControlled {
    constructor(address core) CoreControlled(core) {}
}
