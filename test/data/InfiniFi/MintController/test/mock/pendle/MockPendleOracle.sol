// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPendleOracle} from "@interfaces/pendle/IPendleOracle.sol";

contract MockPendleOracle is IPendleOracle {
    uint256 public ptToSyRate;
    uint256 public ptToAssetRate;

    // disable coverage for this contract
    function test() public view {}

    //TODO: Remove this function
    function mockSetRate(uint256 _rate) external {
        ptToSyRate = _rate;
        ptToAssetRate = _rate;
    }

    function mockSetPtToSyRate(uint256 _rate) external {
        ptToSyRate = _rate;
    }

    function mockSetPtToAssetRate(uint256 _rate) external {
        ptToAssetRate = _rate;
    }

    function getPtToSyRate(address, uint32) external view returns (uint256) {
        return ptToSyRate;
    }

    function getPtToAssetRate(address, uint32) external view returns (uint256) {
        return ptToAssetRate;
    }
}
