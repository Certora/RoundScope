// SPDX-License-Identifier: MIT
// pragma solidity ^0.8;

contract ForcedRounding {

    // Forced Down: dividing by 1 should be detected as rounding down
    function forcedDown(uint256 x) public pure returns (uint256) {
        return x / 1;
    }

    // Forced Up: dividing by 1 then adding 0 should be detected as rounding up
    function forcedUp(uint256 x) public pure returns (uint256) {
        uint256 y = x / 1;
        y = y + 0;
        return y;
    }
}
