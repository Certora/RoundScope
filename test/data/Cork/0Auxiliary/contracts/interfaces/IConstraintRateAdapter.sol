// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IErrors} from "contracts/interfaces/IErrors.sol";
import {MarketId} from "contracts/interfaces/IPoolManager.sol";

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

/// @title IConstraintRateAdapter
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Interface which provides NAV ratio
interface IConstraintRateAdapter is IErrors {
    struct ConstraintState {
        uint256 _lastAdjustedRate;
        uint256 _lastAdjustmentTimestamp;
        uint256 _remainingCredits;
    }

    struct RateCalculationParams {
        uint256 newRate;
        uint256 lastAdjustedRate;
        uint256 remainingCredits;
        uint256 lastAdjustmentTimestamp;
        uint256 currentTimestamp;
        uint256 rateChangePerDayMax;
        uint256 rateChangeCapacityMax;
        uint256 rateMin;
        uint256 rateMax;
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @notice Get the address of the CorkPoolManager contract
    /// @return corkPoolManager The address of the CorkPoolManager contract
    /// slither-disable-next-line naming-convention
    function CORK_POOL_MANAGER() external view returns (address corkPoolManager);

    /// @notice Returns the adjusted rate for a given pool.
    /// @dev This function is used to return the adjusted rate for a given pool.
    /// This function will first fetch the new rate for the given pool,
    /// then calculate the adjusted rate using the constraints specifically designed for this pool, saves the constraints, and return the result.
    /// @param poolId The ID of the pool to return the adjusted rate for.
    /// @return rate The adjusted rate for the given pool.
    function adjustedRate(MarketId poolId) external returns (uint256 rate);

    /// @notice Returns the preview adjusted rate for a given pool.
    /// @dev This function is used to return the preview adjusted rate for a given pool.
    /// This function will first fetch the new rate for the given pool,
    /// then calculate the adjusted rate using the constraints specifically designed for this pool and return the preview result.
    /// @param poolId The ID of the pool to return the preview adjusted rate for.
    /// @return rate The preview adjusted rate for the given pool.
    function previewAdjustedRate(MarketId poolId) external view returns (uint256 rate);

    /// @notice Returns the constraints for a given pool.
    /// @dev This function is used to return the constraints for a given pool.
    /// @param poolId The ID of the pool to return the constraints for.
    /// @return lastAdjustedRate The last adjusted rate for the given pool.
    /// This is the last value of adjusted rate fetched from the pool.
    /// @return lastAdjustmentTimestamp The last adjustment timestamp for the given pool.
    /// This is the block.timestamp when last adjusted rate was updated.
    /// @return remainingCredits The remaining credits for the given pool.
    /// This is the remaining number of credits that can be used to adjust the rate.
    /// This is the rateChangeCapacityMax of the pool
    /// which is the maximum number of credits that can be used to adjust the rate.
    function constraints(MarketId poolId) external view returns (uint256, uint256, uint256);

    ///======================================================///
    ///================== CORE FUNCTIONS ====================///
    ///======================================================///

    /// @notice Bootstraps the constraint rate adapter for a given pool.
    /// @dev This function is used to bootstrap the constraint rate adapter for a given pool.
    /// This function will initialize the constraints for the given pool with the initial values.
    /// Those values are:
    /// - Last adjusted rate: Last value of adjusted rate fetched from the pool
    /// - Last adjustment timestamp: block.timestamp when last adjusted rate was updated
    /// - Remaining credits: rateChangeCapacityMax of the pool
    /// which is the maximum number of credits that can be used to adjust the rate
    /// @param poolId The ID of the pool to bootstrap the constraint rate adapter for.
    function bootstrap(MarketId poolId) external;
}
