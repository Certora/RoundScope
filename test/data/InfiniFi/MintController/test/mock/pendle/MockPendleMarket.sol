// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPendleMarket} from "@interfaces/pendle/IPendleMarket.sol";

contract MockPendleMarket is IPendleMarket {
    uint256 public expiry;
    address public sy;
    address public pt;
    address public yt;

    // disable coverage for this contract
    function test() public view {}

    function mockSetExpiry(uint256 _expiry) external {
        expiry = _expiry;
    }

    function mockSetTokens(address _sy, address _pt, address _yt) external {
        sy = _sy;
        pt = _pt;
        yt = _yt;
    }

    function readTokens() external view returns (address _sy, address _pt, address _yt) {
        return (sy, pt, yt);
    }
}
