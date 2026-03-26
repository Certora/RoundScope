// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {EpochLib} from "@libraries/EpochLib.sol";

contract EpochBasedTest is Test {
    using EpochLib for uint256;

    function testCurrentEpoch() public {
        // Thursday, 28 November 2024 00:00:00 UTC
        uint256 currentTimestmap = 1732752000;
        vm.warp(currentTimestmap);

        // Sunday, 1 December 2024 00:00:00 UTC
        uint256 expectedNewTimestamp = 1733011200;
        uint32 expectedNewEpoch = 2865;

        assertEq(block.timestamp.epoch(), 2864, "Error: Current epoch should be 2864");
        skip(EpochLib.EPOCH_OFFSET);

        assertEq(
            block.timestamp.epoch(), expectedNewEpoch, "Error: Current epoch should be greater than the previous one"
        );
        assertEq(
            block.timestamp, expectedNewTimestamp, "Error: Current timestamp should be equal to expected timestamp"
        );
    }

    function testCurrentEpochExact() public {
        // Thursday, 28 November 2024 00:00:00 UTC
        uint256 currentTimestmap = 1732752000;
        vm.warp(currentTimestmap);

        assertEq(block.timestamp.epoch(), 2864, "Error: Initial epoch (Thursday) should be 2864");
        assertEq(block.timestamp, 1732752000, "Error: Initial timestamp should be 1732752000");

        // Skip to Friday
        skip(1 days);
        assertEq(block.timestamp.epoch(), 2864, "Error: Friday epoch should be 2864");
        assertEq(block.timestamp, 1732838400, "Error: Friday timestamp should be 1732838400");

        // Skip to Saturday
        skip(1 days);
        assertEq(block.timestamp.epoch(), 2864, "Error: Saturday epoch should be 2864");
        assertEq(block.timestamp, 1732924800, "Error: Saturday timestamp should be 1732924800");

        // Skip to Sunday
        skip(1 days);
        assertEq(block.timestamp.epoch(), 2865, "Error: Sunday epoch should be 2865");
        assertEq(block.timestamp, 1733011200, "Error: Sunday timestamp should be 1733011200");
    }

    function testEpochToTimestamp() public {
        // Sunday, 1 December 2024 00:00:00 UTC
        uint256 timestamp = 1733011200;
        uint256 expectedEpoch = 2865;

        vm.warp(timestamp);

        assertEq(block.timestamp.epoch(), expectedEpoch, "Error: Current epoch should be 2865");
        assertEq(expectedEpoch.epochToTimestamp(), timestamp, "Error: Epoch to timestamp should be equal");
    }
}
