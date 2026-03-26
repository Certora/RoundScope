// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "src/locking/UnwindingModule.sol";
import {FixedPointMathLib} from "@solmate/src/utils/FixedPointMathLib.sol";


contract UnwindingHarness is UnwindingModule {
    using EpochLib for uint256;
    using FixedPointMathLib for uint256;


    constructor(address core, address receiptToken) UnwindingModule(core, receiptToken) {}

    function getPosition(address user, uint256 unwindingTimestamp) public view returns (UnwindingPosition memory position) {
        return positions[_unwindingId(user, unwindingTimestamp)];
    }

    function getUnwindingIdHarnessed(address user, uint256 unwindingTimestamp) public view returns (bytes32) {
        return _unwindingId(user, unwindingTimestamp);
    }

    function sharesToAmountHarnessed(uint256 shares) public view returns (uint256) {
        return _sharesToAmount(shares);
    }

    function timestampToEpoch(uint256 timestamp) public view returns (uint256) {
        return timestamp.epoch();
    }

    function rewardWeightWithoutNormalization(address _user, uint256 _startUnwindingTimestamp) external view returns (uint256) {
        UnwindingPosition memory position = positions[_unwindingId(_user, _startUnwindingTimestamp)];
        if (position.fromEpoch == 0) return 0;

        uint256 userRewardWeight = position.fromRewardWeight;
        uint256 currentEpoch = block.timestamp.epoch();
        if (currentEpoch < position.fromEpoch) return 0;
        for (uint32 epoch = position.fromEpoch + 1; epoch <= currentEpoch && epoch <= position.toEpoch; epoch++) {
            userRewardWeight -= position.rewardWeightDecrease;
        }

        return userRewardWeight * slashIndex;
    }
    
    // This is the same as totalRewardWeight but using multipliction 
    // without scaling down
    function totalRewardWeightWithoutNormalization() external view returns (uint256) {
        GlobalPoint memory point = _getLastGlobalPoint();
        return point.totalRewardWeight * slashIndex;
    }

    function totalRewardWeightRoundUp() external view returns (uint256) {
        GlobalPoint memory point = _getLastGlobalPoint();
        return point.totalRewardWeight.mulWadUp(slashIndex);
    }

    function updateLastGlobalPointHarnessed() external {
        GlobalPoint memory point = _getLastGlobalPoint();
        _updateGlobalPoint(point);
    }
}
