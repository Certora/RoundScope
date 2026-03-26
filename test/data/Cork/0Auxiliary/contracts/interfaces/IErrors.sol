// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

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

/// @title IErrors
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Defines custom errors used across core protocol contracts.
interface IErrors {
    /// @notice Trying to initialize the pool more than once.
    error AlreadyInitialized();

    /// @notice Trying to call a setOnce function more than once.
    error AlreadySet();

    /// @notice Trying to swap/remove liquidity from non-initialized pool.
    error NotInitialized();

    /// @notice Trying to swap with invalid amount or adding liquidity without proportion, e.g 0.
    error InvalidAmount();

    /// @notice Zero Address error, thrown when passed address is 0.
    error ZeroAddress();

    /// @notice Thrown when the caller is not the CorkPoolManager contract.
    error NotCorkPoolManager();

    /// @notice Thrown when passed invalid parameters.
    error InvalidParams();

    /// @notice Thrown when the user tries to unwindSwap more than the available Reference Asset + cST liquidity.
    /// @param available The amount of available Reference Asset + Swap Token.
    /// @param requested The amount of Reference Asset + Swap Token user will receive.
    error InsufficientLiquidity(uint256 available, uint256 requested);

    /// @notice Only controller contract is allowed to call this function.
    error OnlyCorkControllerAllowed();

    /// @notice Share is already expired.
    error Expired();

    /// @notice Thrown when user deposit with 0 amount.
    error ZeroDeposit();

    /// @notice Thrown this error when fees are more than 5%.
    error InvalidFees();

    /// @notice Thrown when trying to update rate with invalid rate.
    error InvalidRate();

    /// @notice Thrown when expiry is zero.
    error InvalidExpiry();

    /// @notice Thrown when the pool is not expired.
    error NotExpired();

    /// @notice Thrown when the passed address is invalid.
    error InvalidAddress();

    /// @notice Thrown when the paused status of the pool is the same.
    error SameStatus();

    /// @notice Thrown when the input amount is zero.
    error ZeroAmount();

    /// @notice Thrown when the deadline is exceeded.
    error DeadlineExceeded();

    /// @notice Thrown when the shares amount is too small and would result in 0 output due to decimals rounding.
    error InsufficientSharesAmount(uint256 minimumRequired, uint256 provided);

    /// @notice Thrown when an input amount does not meet some minimum value requirements.
    error InsufficientAmount();

    /// @notice Thrown when an account is not whitelisted for a specific market.
    /// @param account the account that is not whitelisted.
    /// @param marketId the market for which the account is not whitelisted.
    error NotWhitelisted(address account, bytes32 marketId);

    /// @notice Thrown when the whitelist is already disabled.
    error WhitelistAlreadyDisabled();
}
