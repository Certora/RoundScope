// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "src/locking/LockingController.sol";

contract LockingControllerHarness is LockingController {
    constructor(address _core, address _receiptToken, address _unwindingModule) LockingController(_core, _receiptToken, _unwindingModule) {}

    function ensureEnabledBucketsDiffer() public { 
        require (enabledBuckets[0] != enabledBuckets[1]); 
    } 
}