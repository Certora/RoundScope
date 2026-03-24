pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../munged/pool-stable-phantom/contracts/StablePhantomPool.sol";

// This is the contract that is actually verified; it may contain some helper
// methods for the spec to access internal state, or may override some of the
// more complex methods in the original contract.
contract StablePhantomPoolHarness is StablePhantomPool {
    constructor(NewPoolParams memory params) StablePhantomPool(params) {}
}

