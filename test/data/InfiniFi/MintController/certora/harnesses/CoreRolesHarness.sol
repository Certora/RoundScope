// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract CoreRolesHarness {

    function governorRole() external returns (bytes32) {
        return keccak256("GOVERNOR");
    }

    function pauseRole() external returns (bytes32) {
        return keccak256("PAUSE");
    }

    function unpauseRole() external returns (bytes32) {
        return keccak256("UNPAUSE");
    }

    function entryPointRole() external returns (bytes32) {
        return keccak256("ENTRY_POINT");
    }

    function financeManagerRole() external returns (bytes32) {
        return keccak256("FINANCE_MANAGER");
    }

    function lockedTokenManagerRole() external returns (bytes32) {
        return keccak256("LOCKED_TOKEN_MANAGER");
    }

    function protocolParametersRole() external returns (bytes32) {
        return keccak256("PROTOCOL_PARAMETERS");
    }
}