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

/// @title MathHelper
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice MathHelper Library which implements Helper functions for Math
library MathHelper {
    using Math for uint256;

    /// @dev amount = referenceAsset x swapRate
    /// calculate how much Swap Token(need to be provided) and Collateral Asset(user will receive) in respect to the swap rate
    /// @param referenceAsset the amount of referenceAsset user provides
    /// @param swapRate the current swap rate
    /// @return amount the amount of Collateral Asset user will receive & Swap Token needs to be provided
    function calculateEqualSwapAmount(uint256 referenceAsset, uint256 swapRate) internal pure returns (uint256 amount) {
        amount = referenceAsset.mulDiv(swapRate, 1e18, Math.Rounding.Floor);
    }

    /// @dev calculate the fee amount in respect to the given fees percentage and asset amount
    /// @param fee1e18 the fee percentage in 1e18
    /// @param amount the amount for which the fee is calculated
    /// @return feeAmount the amount of fee
    function calculatePercentageFee(uint256 fee1e18, uint256 amount) internal pure returns (uint256 feeAmount) {
        feeAmount = amount.mulDiv(fee1e18, 100e18, Math.Rounding.Ceil);
    }

    /// @dev calculate how much reference asset + swapToken user will receive based on the current swap rate
    /// @param amount  the amount of user deposit
    /// @param swapRate the current swap rate
    /// @param isRoundUp whether to round up or down
    function calculateDepositAmountWithSwapRate(uint256 amount, uint256 swapRate, bool isRoundUp)
        internal
        pure
        returns (uint256)
    {
        if (isRoundUp) return amount.mulDiv(1e18, swapRate, Math.Rounding.Ceil);
        else return amount.mulDiv(1e18, swapRate, Math.Rounding.Floor);
    }

    /// @notice calculate the accrued Assets
    /// @param cptSharesIn the amount of cPT shares being used
    /// @param availableAssets the amount of available assets (collateral or reference)
    /// @param cptTotalSupply the principal token supply
    /// @return accruedAssets the amount of accrued assets
    /// @dev this function follow below equation :
    /// '#' refers to the total circulation supply of that token.
    /// '&' refers to the total amount of token in the Cork Pool.
    /// amount * &Reference Asset or &Collateral Asset / #Principal Token
    function calculateAccrued(uint256 cptSharesIn, uint256 availableAssets, uint256 cptTotalSupply)
        internal
        pure
        returns (uint256 accruedAssets)
    {
        if (cptSharesIn == 0 || cptTotalSupply == 0) return 0;
        accruedAssets = cptSharesIn.mulDiv(availableAssets, cptTotalSupply, Math.Rounding.Floor);
    }

    /// @notice returns the normalized time to maturity from 1-0
    /// @param start the start time
    /// @param end the end time
    /// @param current the current time
    /// @return the normalized time to maturity from 1-0
    /// @dev 1 means we're at the start of the period, 0 means we're at the end
    function computeT(uint256 start, uint256 end, uint256 current) internal pure returns (uint256) {
        uint256 elapsedTime = current - start;
        elapsedTime = elapsedTime == 0 ? 1 : elapsedTime;
        uint256 totalDuration = end - start;

        // we return 0 in case it's past maturity time
        if (elapsedTime >= totalDuration) return 0;

        // Return a normalized time between 0 and 1 (as a percentage in 18 decimals)
        return ((totalDuration - elapsedTime) * 1e18) / totalDuration;
    }

    /// @notice calculate the gross amount with time decay fee
    /// @param start the start time
    /// @param end the end time
    /// @param current the current time
    /// @param amount the amount of assets
    /// @param baseFeePercentage the base fee percentage
    /// @return fee the amount of fee
    /// @return assetIn the amount of assets with fee
    function calculateGrossAmountWithTimeDecayFee(
        uint256 start,
        uint256 end,
        uint256 current,
        uint256 amount,
        uint256 baseFeePercentage
    ) internal pure returns (uint256 fee, uint256 assetIn) {
        if (amount == 0) return (0, 0);

        uint256 t = computeT(start, end, current);

        uint256 feeFactor = baseFeePercentage.mulDiv(t, 1e18, Math.Rounding.Ceil);

        uint256 withFee = amount.mulDiv(100e18, (100e18 - feeFactor), Math.Rounding.Ceil);

        assetIn = withFee;
        fee = (assetIn - amount);
    }

    /// @notice calculate the time decay fee
    /// @param start the start time
    /// @param end the end time
    /// @param current the current time
    /// @param amount the amount of assets
    /// @param baseFeePercentage the base fee percentage
    /// @return fee the amount of fee
    function calculateTimeDecayFee(
        uint256 start,
        uint256 end,
        uint256 current,
        uint256 amount,
        uint256 baseFeePercentage
    ) internal pure returns (uint256 fee) {
        if (amount == 0) return 0;

        uint256 t = computeT(start, end, current);

        uint256 feeFactor = baseFeePercentage.mulDiv(t, 1e18, Math.Rounding.Ceil);

        fee = amount.mulDiv(feeFactor, 100e18, Math.Rounding.Ceil);
    }

    /// @notice calculate the required shares needed to get a specific amount of assets
    /// @param amount the amount of assets
    /// @param available the amount of available assets
    /// @param cptTotalSupply the principal token supply
    /// @return shares the amount of shares
    /// @dev this function reverses the calculateAccrued equation:
    /// amount = shares * (available / cptTotalSupply)
    /// therefore: shares = amount * (cptTotalSupply / available)
    function calculateSharesNeeded(uint256 amount, uint256 available, uint256 cptTotalSupply)
        internal
        pure
        returns (uint256 shares)
    {
        if (amount == 0 || cptTotalSupply == 0 || available == 0) return 0;
        shares = amount.mulDiv(cptTotalSupply, available, Math.Rounding.Ceil);
    }

    /// @notice calculate the gross amount needed before fee deduction to achieve a desired net amount
    /// @param desiredAmount the amount you want to receive after fees
    /// @param feeRate the fee percentage in 1e18 format (e.g., 5e18 = 5%)
    /// @return grossAmount the gross amount needed before fee deduction
    /// @dev grossAmount = desiredAmount ÷ (1 - feeRate) => grossAmount = (desiredAmount * 100e18)÷ (100e18 - rate in 100e18)
    function calculateGrossAmountBeforeFee(uint256 desiredAmount, uint256 feeRate)
        internal
        pure
        returns (uint256 grossAmount)
    {
        // grossAmount = desiredAmount ÷ (1 - feeRate)
        // So grossAmount = (desiredAmount * 100e18)÷ (100e18 - rate in 100e18)
        // Where rate in 100e18 means => 1% = 1e18
        grossAmount = desiredAmount.mulDiv(100e18, 100e18 - feeRate, Math.Rounding.Ceil);
    }
}
