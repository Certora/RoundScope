// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Extsload} from "contracts/core/Extsload.sol";
import {IErrors} from "contracts/interfaces/IErrors.sol";
import {MarketId} from "contracts/interfaces/IPoolManager.sol";
import {PoolLibrary} from "contracts/libraries/PoolLib.sol";
import {State} from "contracts/libraries/State.sol";

//             CCCCCCCCC  C
//          CCCCCCCCCCC   C
//       CCCCCCCCCCCCCC   C
//     CCCCCCCCCCCCCCCC   C        CCCCCC                    CCCCCCCCCCCCCCC             CCCCCCCCCCCCCCC     CCCCCCCCCCCCCCCCCCCC     CCCCCCCCCCC     CCCCCCCCCC
//    CCCCCCCCCCCCCCCCC CC       CCCCCC  C               CCCCCCCCCCCCCCCCCC  CCC     CCCCCCCCCCCCCCCCCC  CC  CCCCCCCCCCCCCCCCCCCC  CC CCCCCCC   C    CCCCCCCC  CC
//   CCCCCCCCCCCCCCCC CC       CCCCCCCCC  C            CCCCCCCCCCCCCCCCCCCCC    CC CCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCCC   C    CCCCCCCC  CC
//  CCCCCCCCCCCCCCC CC        CCCCCCCCCCC  C          CCCCCCCCCCCCCCCCCCCCCCCC    CCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCC   C  CCCCCCCCCC  CC
// CCCCCCCCCCCCCC CC        CCCCCCCCCCCCC  CC        CCCCCCCCC    CC  CCCCCCCCC  CCCCCCCCC   CC   CCCCCCCCC  CCCCCCC    C   CCCCCCCC  CCCCCCC   CCCCCCCCCCC  CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C        CCCCCCCC    CC     CCCCCCCCCCCCCCCC    CC     CCCCCCCC  CCCCCCC    C    CCCCCCC  CCCCCCC  CCCCCCCCCC  CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C       CCCCCCCC    CC              CCCCCCCC   CC       CCCCCCCC CCCCCCC    C   CCCCCCCC  CCCCCCC  CCCCCCCC   C
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC   C      CCCCCCCC    C               CCCCCCCC   C        CCCCCCCC CCCCCCCCCCCCCCCCCCCCCCC  CCCCCCC  CCCCCCCC   C
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C       CCCCCCCC    CC              CCCCCCCC   CC       CCCCCCCC CCCCCCCCCCCCCCCCCCCCC   CCCCCCCC  CCCCCCCC   CC
// CCCCCCCCCCCC  C         CCCCCCCCCCCCCCC  C        CCCCCCCC    CC     CCCCCCCCCCCCCCCC    CC     CCCCCCCC  CCCCCCCCCCCCCCCCCCC   CC CCCCCCC  CCCCCCCCCC   C
// CCCCCCCCCCCCCC CC        CCCCCCCCCCCCC  CC        CCCCCCCCC    CCC CCCCCCCCC  CCCCCCCCC   CCC  CCCCCCCCC  CCCCCCCCCCCCCCCCCCCCC   CCCCCCCC   CCCCCCCCCCC  CC
//  CCCCCCCCCCCCCCC CC        CCCCCCCCCCC  C          CCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCCCCCCCCCCCCCCCCCCCC   CCCCCCC    C CCCCCCCCCC  CCCCCCC   C  CCCCCCCCCC  CC
//   CCCCCCCCCCCCCCCC CC        CCCCCCCC  C            CCCCCCCCCCCCCCCCCCCCC    CC CCCCCCCCCCCCCCCCCCCCCC  CCCCCCCCC    C   CCCCCCCC  CCCCCCC   C    CCCCCCCC  CC
//    CCCCCCCCCCCCCCCC  CC        CCCCC CC                CCCCCCCCCCCCCCCC   CC      CCCCCCCCCCCCCCCCC  CCC  CCCCCCC    C   CCCCCCCC  CCCCCCC   C    CCCCCCCC  CC
//     CCCCCCCCCCCCCCCC   C        CCCCCC                    CCCCCCCCCCCCCCC             CCCCCCCCCCCCCC      CCCCCCCCCCCC    CCCCCCCCCCCCCCCCCCCC     CCCCCCCCCC
//       CCCCCCCCCCCCCC   C
//          CCCCCCCCCCC   C
//              CCCCCCCCCCC

/// @title CorkPoolManagerStorage
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Abstract storage contract providing ERC-7201 namespaced storage for CorkPoolManager.
abstract contract CorkPoolManagerStorage is ReentrancyGuard, Extsload, IErrors {
    using PoolLibrary for State;

    struct Storage {
        mapping(MarketId => State) states;
        address SHARES_FACTORY;
        address CONSTRAINT_ADAPTER;
        address TREASURY;
        address WHITELIST_MANAGER;
    }

    // ERC-7201 Namespaced Storage Layout.
    // keccak256(abi.encode(uint256(keccak256("cork.storage.CorkPoolManagerStorage")) - 1)) & ~bytes32(uint256(0xff)) = 0xca60d71d44db08890954961692d4c0e9107284a789e12b27f483ad59d898d200
    bytes32 private constant _CORK_POOL_MANAGER_STORAGE_POSITION =
        0xca60d71d44db08890954961692d4c0e9107284a789e12b27f483ad59d898d200;

    ///======================================================///
    ///================= INITIALIZATION FUNCTIONS ===========///
    ///======================================================///

    /// @notice Initializes the CorkPoolManagerStorage.
    function initializeCorkPoolManagerStorage(address constraintRateAdapter, address treasury, address whitelistManager)
        internal
    {
        require(
            constraintRateAdapter != address(0) && treasury != address(0) && whitelistManager != address(0),
            ZeroAddress()
        );

        Storage storage ms = data();
        ms.CONSTRAINT_ADAPTER = constraintRateAdapter;
        ms.TREASURY = treasury;
        ms.WHITELIST_MANAGER = whitelistManager;
    }

    ///======================================================///
    ///================= VIEW FUNCTIONS =====================///
    ///======================================================///

    /// @notice Returns the address of the treasury.
    function _getTreasuryAddress() internal view returns (address) {
        return data().TREASURY;
    }

    /// @notice Returns the address of the constraint rate adapter.
    function _getConstraintRateAdapter() internal view returns (address) {
        return data().CONSTRAINT_ADAPTER;
    }

    /// @notice Returns the address of the whitelist manager.
    function _getWhitelistManager() internal view returns (address) {
        return data().WHITELIST_MANAGER;
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    function data() internal pure returns (Storage storage ms) {
        // slither-disable-next-line assembly
        assembly {
            ms.slot := _CORK_POOL_MANAGER_STORAGE_POSITION
        }
    }

    function _onlyInitialized(MarketId id) internal view {
        require(data().states[id].isInitialized(), NotInitialized());
    }
}
