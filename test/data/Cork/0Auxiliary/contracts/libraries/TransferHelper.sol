// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

/// @title TransferHelper
/// @author Cork Team
/// @custom:security-contact security@cork.tech
library TransferHelper {
    using Math for uint256;

    /// @dev This is the default decimals in the protocol.
    /// Shares of any pool (cST and cPT) will always have these decimals.
    uint8 internal constant TARGET_DECIMALS = 18;

    /// @notice Normalizes the decimals of an amount to a target decimals.
    /// @dev This is useful if you're targeting a lower decimals and want to round down the resulting number.
    /// @dev This will effectively round down the returned amount when `decimalsCurrent` > `decimalsAfter`.
    /// @dev For rounding up behaviour, use `normalizeDecimalsWithCeilDiv`.
    /// @param amount The amount to normalize. This MUST be in `decimalsCurrent`.
    /// @param decimalsCurrent The current amount decimals.
    /// @param decimalsAfter The target decimals to normalize.
    /// @return normalizedAmount The normalized amount in `decimalsAfter`.
    function normalizeDecimals(uint256 amount, uint8 decimalsCurrent, uint8 decimalsAfter)
        internal
        pure
        returns (uint256 normalizedAmount)
    {
        // If we need to increase the decimals.
        if (decimalsCurrent > decimalsAfter) {
            // Then we divide the amount by the number of decimals difference.
            amount = amount / 10 ** (decimalsCurrent - decimalsAfter);

            // If we need to decrease the number.
        } else if (decimalsCurrent < decimalsAfter) {
            // Then we multiply by the difference in decimals.
            amount = amount * 10 ** (decimalsAfter - decimalsCurrent);
        }

        // If nothing changed this is a no-op.
        normalizedAmount = amount;
    }

    /// @notice Normalizes the decimals of an amount to a target decimals using ceil division.
    /// @dev This is useful if you're targeting a lower decimals and want to round up the resulting number.
    /// @dev This will effectively round up the returned amount when `decimalsCurrent` > `decimalsAfter`.
    /// @dev For rounding down behaviour use `normalizeDecimals`.
    /// @param amount The amount to normalize. This MUST be in `decimalsCurrent`.
    /// @param decimalsCurrent The current amount decimals.
    /// @param decimalsAfter The target decimals to normalize.
    /// @return normalizedAmount The normalized amount in `decimalsAfter`.
    function normalizeDecimalsWithCeilDiv(uint256 amount, uint8 decimalsCurrent, uint8 decimalsAfter)
        internal
        pure
        returns (uint256 normalizedAmount)
    {
        // If we need to increase the decimals.
        if (decimalsCurrent > decimalsAfter) {
            // Then we divide the amount by the number of decimals difference, rounding up.
            amount = amount.ceilDiv(10 ** (decimalsCurrent - decimalsAfter));

            // If we need to decrease the number.
        } else if (decimalsCurrent < decimalsAfter) {
            // then we multiply by the difference in decimals.
            amount = amount * 10 ** (decimalsAfter - decimalsCurrent);
        }

        // If nothing changed this is a no-op.
        normalizedAmount = amount;
    }

    /// @notice Normalize amount in a token native decimals amount to a fixed decimals amount(18).
    /// @dev This will round down the resulting number in case the native decimals < 18.
    /// @param amount The amount to normalize to a fixed decimals amount.
    /// @param decimals Decimals of the native token.
    /// @return The Normalized amount.
    function tokenNativeDecimalsToFixed(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return normalizeDecimals(amount, decimals, TARGET_DECIMALS);
    }

    /// @notice Normalize a fixed decimals (18) amount to token native decimals.
    /// @dev This will round down the resulting number in case the native decimals < 18.
    /// @param amount The amount to normalize to a token native decimals amount.
    /// @param decimals Decimals of the native token.
    /// @return The Normalized amount.
    function fixedToTokenNativeDecimals(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return normalizeDecimals(amount, TARGET_DECIMALS, decimals);
    }

    /// @notice Normalize a fixed decimals (18) amount to token native decimals with ceil division.
    /// @dev This will round up the resulting number in case the native decimals < 18.
    /// @param amount The amount to normalize to a token native decimals amount.
    /// @param decimals Decimals of the native token.
    /// @return The Normalized amount.
    function fixedToTokenNativeDecimalsWithCeilDiv(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return normalizeDecimalsWithCeilDiv(amount, TARGET_DECIMALS, decimals);
    }
}
