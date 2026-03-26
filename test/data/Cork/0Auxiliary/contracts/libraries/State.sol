// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Market} from "contracts/interfaces/IPoolManager.sol";

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

/// @dev State structure.
/// @dev As there are some fields that are used in Cork Pool but not in LV.
struct State {
    Market info;
    /// @dev epoch => Shares(Principal Token + Swap Token)
    Shares shares;
    PoolState pool;
    /// @dev decimals of the reference asset token.
    uint8 referenceDecimals;
    /// @dev decimals of the collateral asset token.
    uint8 collateralDecimals;
}

/// @dev Struct for shares.
struct Shares {
    address swap;
    address principal;
    uint256 withdrawn;
}

/// @dev CollateralAssetManager struct for managing collateral asset.
struct CollateralAssetManager {
    address _address;
    uint256 locked;
}

/// @notice Represents the full state of a Cork Pool within the Core contract.
/// @dev The `pauseBitMap` field encodes pause states for different pool operations.
/// @dev The mapping of bit positions to operations is as follows:
/// @dev - Bit 0 → Deposit operations (`isDepositPaused`)
/// @dev - Bit 1 → Swap operations (`isSwapPaused`)
/// @dev - Bit 2 → Withdrawal operations (`isWithdrawalPaused`)
/// @dev - Bit 3 → Unwind deposit operations (`isUnwindDepositPaused`)
/// @dev - Bit 4 → Unwind swap operations (`isUnwindSwapPaused`)
struct PoolState {
    Balances balances;
    uint256 unwindSwapFeePercentage;
    CorkPoolPoolArchive poolArchive;
    bool liquiditySeparated;
    uint16 pauseBitMap;
    uint256 swapFeePercentage;
}

/// @dev CorkPoolPoolArchive structure for Cork Pool Pools.
struct CorkPoolPoolArchive {
    uint256 collateralAssetAccrued;
    uint256 referenceAssetAccrued;
}

/// @dev Balances structure for managing balances in Cork Pool Core.
struct Balances {
    CollateralAssetManager collateralAsset;
    uint256 swapTokenBalance;
    uint256 referenceAssetBalance;
}
