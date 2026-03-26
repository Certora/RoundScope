// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {Fixture} from "@test/Fixture.t.sol";
import {CoreRoles} from "@libraries/CoreRoles.sol";

contract TimelockUnitTest is Fixture {
    uint256 public _LONG_TIMELOCK_DELAY = 30 days;

    uint256 __lastCallValue = 0;

    function __dummyCall(uint256 val) external {
        __lastCallValue = val;
    }

    function setUp() public override {
        super.setUp();
    }

    function testInitialState() public view {
        assertEq(address(longTimelock.core()), address(core), "Error: Invalid longTimelock core() address");
        assertEq(longTimelock.getMinDelay(), _LONG_TIMELOCK_DELAY, "Error: Invalid longTimelock delay");
    }

    function testAccessControlUsesCore() public view {
        assertEq(
            longTimelock.hasRole(CoreRoles.EXECUTOR_ROLE, address(0)),
            true,
            "Error: Invalid access control storage used"
        );
    }

    function testScheduleBatchExecuteBatch() public {
        // function parameters
        address[] memory targets = new address[](1);
        targets[0] = address(this);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(TimelockUnitTest.__dummyCall.selector, 12345);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256(bytes("dummy call"));

        // get batch id
        bytes32 id = longTimelock.hashOperationBatch(targets, values, payloads, 0, salt);

        // grant proposer and executor role to self
        vm.startPrank(governorAddress);
        core.grantRole(CoreRoles.PROPOSER_ROLE, address(this));
        core.grantRole(CoreRoles.EXECUTOR_ROLE, address(this));
        vm.stopPrank();

        assertEq(longTimelock.getTimestamp(id), 0);
        assertEq(longTimelock.isOperation(id), false);
        assertEq(longTimelock.isOperationPending(id), false);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), false);

        // schedule batch
        longTimelock.scheduleBatch(targets, values, payloads, predecessor, salt, _LONG_TIMELOCK_DELAY);

        assertEq(longTimelock.getTimestamp(id), block.timestamp + _LONG_TIMELOCK_DELAY);
        assertEq(longTimelock.isOperation(id), true);
        assertEq(longTimelock.isOperationPending(id), true);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), false);

        // fast forward time
        vm.warp(block.timestamp + _LONG_TIMELOCK_DELAY);

        assertEq(longTimelock.isOperation(id), true);
        assertEq(longTimelock.isOperationPending(id), true);
        assertEq(longTimelock.isOperationReady(id), true);
        assertEq(longTimelock.isOperationDone(id), false);

        // execute
        longTimelock.executeBatch(targets, values, payloads, predecessor, salt);

        assertEq(longTimelock.getTimestamp(id), 1); // _DONE_TIMESTAMP = 1
        assertEq(longTimelock.isOperation(id), true);
        assertEq(longTimelock.isOperationPending(id), false);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), true);
    }

    function testScheduleBatchCancel() public {
        // function parameters
        address[] memory targets = new address[](1);
        targets[0] = address(this);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);
        payloads[0] = abi.encodeWithSelector(TimelockUnitTest.__dummyCall.selector, 12345);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256(bytes("dummy call"));

        // get batch id
        bytes32 id = longTimelock.hashOperationBatch(targets, values, payloads, 0, salt);

        // grant proposer and canceller role to self
        vm.startPrank(governorAddress);
        core.grantRole(CoreRoles.PROPOSER_ROLE, address(this));
        core.grantRole(CoreRoles.CANCELLER_ROLE, address(this));
        vm.stopPrank();

        assertEq(longTimelock.getTimestamp(id), 0);
        assertEq(longTimelock.isOperation(id), false);
        assertEq(longTimelock.isOperationPending(id), false);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), false);

        // schedule batch
        longTimelock.scheduleBatch(targets, values, payloads, predecessor, salt, _LONG_TIMELOCK_DELAY);

        assertEq(longTimelock.getTimestamp(id), block.timestamp + _LONG_TIMELOCK_DELAY);
        assertEq(longTimelock.isOperation(id), true);
        assertEq(longTimelock.isOperationPending(id), true);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), false);

        // cancel
        longTimelock.cancel(id);

        assertEq(longTimelock.getTimestamp(id), 0);
        assertEq(longTimelock.isOperation(id), false);
        assertEq(longTimelock.isOperationPending(id), false);
        assertEq(longTimelock.isOperationReady(id), false);
        assertEq(longTimelock.isOperationDone(id), false);
    }

    function testUpdateDelay() public {
        // only the longTimelock can update its own delay
        vm.expectRevert(abi.encodeWithSelector(TimelockController.TimelockUnauthorizedCaller.selector, address(this)));
        longTimelock.updateDelay(_LONG_TIMELOCK_DELAY / 2);

        // grant proposer and executor role to self
        vm.startPrank(governorAddress);
        core.grantRole(CoreRoles.PROPOSER_ROLE, address(this));
        core.grantRole(CoreRoles.EXECUTOR_ROLE, address(this));
        vm.stopPrank();

        // schedule an action to update delay
        bytes memory data = abi.encodeWithSelector(TimelockController.updateDelay.selector, _LONG_TIMELOCK_DELAY / 2);
        bytes32 id =
            longTimelock.hashOperation(address(longTimelock), 0, data, bytes32(0), keccak256(bytes("dummy call")));
        assertEq(longTimelock.isOperation(id), false);
        longTimelock.schedule(
            address(longTimelock), // address target
            0, // uint256 value
            data, // bytes data
            bytes32(0), // bytes32 predecessor
            keccak256(bytes("dummy call")), // bytes32 salt
            _LONG_TIMELOCK_DELAY // uint256 delay
        );
        assertEq(longTimelock.isOperation(id), true);

        // fast forward in time & execute
        vm.warp(block.timestamp + _LONG_TIMELOCK_DELAY);
        longTimelock.execute(
            address(longTimelock), // address target
            0, // uint256 value
            data, // bytes data
            bytes32(0), // bytes32 predecessor
            keccak256(bytes("dummy call")) // bytes32 salt
        );
        assertEq(longTimelock.isOperationDone(id), true);
        assertEq(longTimelock.getMinDelay(), _LONG_TIMELOCK_DELAY / 2);
    }
}
