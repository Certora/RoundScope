// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockERC20} from "@test/mock/MockERC20.sol";

/// @notice Mock AToken contract for testing
contract MockAToken is MockERC20 {
    uint256 public multiplier = 1e18;

    constructor(string memory _name, string memory _symbol) MockERC20(_name, _symbol) {}

    // disable coverage for this contract
    function test() public pure override {}

    function setMultiplier(uint256 _multiplier) external {
        multiplier = _multiplier;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) * multiplier / 1e18;
    }
}
