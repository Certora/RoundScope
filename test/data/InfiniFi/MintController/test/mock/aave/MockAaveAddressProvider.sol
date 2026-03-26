// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAddressProvider} from "@interfaces/aave/IAddressProvider.sol";

contract MockAaveAddressProvider is IAddressProvider {
    address public poolProvider;

    constructor(address _poolProvider) {
        poolProvider = _poolProvider;
    }

    // disable coverage for this contract
    function test() public view {}

    function getPoolDataProvider() external view returns (address) {
        return poolProvider;
    }

    function setPoolProvider(address _poolProvider) external {
        poolProvider = _poolProvider;
    }
}
