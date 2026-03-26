// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PoolShare} from "contracts/core/assets/PoolShare.sol";
import {IConstraintRateAdapter} from "contracts/interfaces/IConstraintRateAdapter.sol";
import {IErrors} from "contracts/interfaces/IErrors.sol";
import {Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {MathHelper} from "contracts/libraries/MathHelper.sol";
import {CollateralAssetManager, CorkPoolPoolArchive, Shares, State} from "contracts/libraries/State.sol";
import {TransferHelper} from "contracts/libraries/TransferHelper.sol";

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

/// @title PoolLib
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Implements functions for core contracts.
library PoolLibrary {
    using SafeERC20 for IERC20;

    ///   This denotes maximum fee allowed in contract.
    ///   Here 1 ether = 1e18 so maximum 5% fee allowed.
    uint256 internal constant MAX_ALLOWED_FEES = 5 ether;

    ///======================================================///
    ///================ INITIALIZATION FUNCTIONS ============///
    ///======================================================///

    /// @notice Initializes the pool.
    /// @param self The state of the pool.
    /// @param poolId The ID of the pool.
    /// @param market The market information.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    function initialize(State storage self, MarketId poolId, Market calldata market, address constraintRateAdapter)
        external
    {
        self.info = market;
        self.pool.balances.collateralAsset = CollateralAssetManager({_address: market.collateralAsset, locked: 0});

        // slither-disable-next-line reentrancy-no-eth
        IConstraintRateAdapter(constraintRateAdapter).bootstrap(poolId);
    }

    ///======================================================///
    ///================ PREVIEW FUNCTIONS ===================///
    ///======================================================///

    /// @notice Simulates redeem operation to preview asset amounts that would be received.
    /// @param self The state of the pool.
    /// @param cptSharesIn Amount of cPT shares to simulate burning (18 decimals).
    /// @return referenceAssetsOut Reference asset amount that would be received (native reference decimals).
    /// @return collateralAssetsOut Collateral asset amount that would be received (native collateral decimals).
    function previewRedeem(State storage self, uint256 cptSharesIn)
        public
        view
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut)
    {
        if (!_isExpired(self)) return (0, 0);
        if (cptSharesIn == 0) return (0, 0);
        if (_isWithdrawalPaused(self)) return (0, 0);

        Shares storage tokens = self.shares;

        // Calculate minimum shares to avoid rounding issues for low decimal tokens.
        uint8 collateralDecimals = self.collateralDecimals;
        uint8 referenceDecimals = self.referenceDecimals;

        // Use the asset with the lowest decimals to calculate minimum shares.
        uint8 lowestDecimals = collateralDecimals < referenceDecimals ? collateralDecimals : referenceDecimals;
        uint256 minimumShares = 10 ** (18 - lowestDecimals);

        // Check if amount of cPT shares is less than minimum shares.
        if (cptSharesIn < minimumShares) return (0, 0); // Return 0 for preview to indicate it's below minimum.

        // Check if liquidity has been separated for this Swap Token.
        if (!self.pool.liquiditySeparated) {
            // If not separated, we need to simulate the separation to get accurate preview.
            // This simulates what _separateLiquidity would do.
            uint256 availableCollateralAsset = self.pool.balances.collateralAsset.locked;
            uint256 availableReferenceAsset = self.pool.balances.referenceAssetBalance;

            (referenceAssetsOut, collateralAssetsOut) = _calcSwapAmount(
                cptSharesIn, IERC20(tokens.principal).totalSupply(), availableCollateralAsset, availableReferenceAsset
            );
        } else {
            // Liquidity already separated, use archived values.
            CorkPoolPoolArchive storage archive = self.pool.poolArchive;

            (referenceAssetsOut, collateralAssetsOut) = _calcSwapAmount(
                cptSharesIn,
                IERC20(tokens.principal).totalSupply(),
                archive.collateralAssetAccrued,
                archive.referenceAssetAccrued
            );
        }
    }

    /// @notice Simulate withdraw operation to preview the required cPT shares to burn and the collateral assets and reference assets received.
    /// @param self The state of the pool.
    /// @param collateralAssetsOut Desired amount of collateral assets to withdraw (native collateral decimals).
    /// @return cptSharesIn cPT shares that would need to be burned.
    /// @return actualCollateralAssetsOut Collateral assets that would be withdrawn.
    /// @return actualReferenceAssetsOut Reference assets that would be withdrawn.
    function previewWithdraw(State storage self, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        // collateralAssetsOut MUST be non-zero.
        if (collateralAssetsOut == 0) revert IErrors.InvalidAmount();

        return _previewWithdraw(self, collateralAssetsOut, 0);
    }

    /// @notice Simulates withdrawOther operation to preview required cPT shares burn and asset amounts received.
    /// @param referenceAssetsOut Desired amount of reference asset to withdraw (native reference decimals).
    /// @return cptSharesIn cPT shares that would need to be burned.
    /// @return actualCollateralAssetsOut Proportional collateral amount that would be withdrawn.
    /// @return actualReferenceAssetsOut Reference amount that would be withdrawn.
    function previewWithdrawOther(State storage self, uint256 referenceAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        // referenceAssetsOut MUST be non-zero.
        if (referenceAssetsOut == 0) revert IErrors.InvalidAmount();

        return _previewWithdraw(self, 0, referenceAssetsOut);
    }

    /// @notice Simulates exercise operation to preview collateral received and costs.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesIn Amount of cST shares to simulate exercising (18 decimals).
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsOut Collateral assets that would be received.
    /// @return referenceAssetsIn Reference assets spent.
    /// @return fee Protocol fee that would be charged. In collateral assets.
    function previewExercise(State storage self, MarketId poolId, uint256 cstSharesIn, address constraintRateAdapter)
        internal
        view
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee)
    {
        // slither-disable-next-line incorrect-equality
        if (cstSharesIn == 0) return (0, 0, 0);
        if (_isSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

        // We need to provide referenceAssetsIn = cstSharesIn / swapRate.
        referenceAssetsIn = TransferHelper.fixedToTokenNativeDecimalsWithCeilDiv(
            MathHelper.calculateDepositAmountWithSwapRate(cstSharesIn, _swapRate, true), self.referenceDecimals
        );

        (collateralAssetsOut, fee) = _getPreviewExerciseFeeAndCollateralAssetsOut(self, cstSharesIn);
    }

    /// @notice Simulates exercise operation to preview collateral received and costs.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsIn Amount of reference assets to simulate exercising.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsOut Amount of collateral assets that would be received.
    /// @return cstSharesIn Amount of cST shares that would be spent.
    /// @return fee Protocol fee that would be charged. In collateral assets.
    function previewExerciseOther(
        State storage self,
        MarketId poolId,
        uint256 referenceAssetsIn,
        address constraintRateAdapter
    ) internal view returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee) {
        // slither-disable-next-line incorrect-equality
        if (referenceAssetsIn == 0) return (0, 0, 0);
        if (_isSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

        // We need to provide cstShares = referenceAssetsIn x swapRate.
        cstSharesIn = MathHelper.calculateEqualSwapAmount(
            TransferHelper.tokenNativeDecimalsToFixed(referenceAssetsIn, self.referenceDecimals), _swapRate
        );

        (collateralAssetsOut, fee) = _getPreviewExerciseFeeAndCollateralAssetsOut(self, cstSharesIn);
    }

    /// @notice Simulates swap operation to preview required cST shares and reference assets payments.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @param collateralAssetsOut Amount of collateral assets to simulate unlocking.
    /// @return cstSharesIn Amount of cST shares that would need to be locked.
    /// @return referenceAssetsIn Reference assets that would need to be paid.
    /// @return fee Protocol fee that would be charged.
    function previewSwap(
        State storage self,
        MarketId poolId,
        uint256 collateralAssetsOut,
        address constraintRateAdapter
    ) public view returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee) {
        if (collateralAssetsOut == 0) return (0, 0, 0);
        if (_isSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        uint256 exchangeRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

        // Calculate gross collateral amount needed before fee deduction.
        uint256 grossCollateralAssets =
            MathHelper.calculateGrossAmountBeforeFee(collateralAssetsOut, self.pool.swapFeePercentage);

        // Convert gross collateral to fixed decimals to get cST shares needed.
        cstSharesIn = TransferHelper.tokenNativeDecimalsToFixed(grossCollateralAssets, self.collateralDecimals);
        // Fee in collateral assets. we basically mark up how much shares and reference assets user should provide us in exchange for the exact amount they requested.
        // In reality, there's leftover collateral that hasn't been distributed.
        // Imagine : rate = 1, fee = 5%
        // 1. User provides ~1.052 shares and exactly 1 reference asset
        // 2. User should get ~1.052 collateral assets but they get only 1, with the rest of the ~0.052 collateral assets go to treasury.
        fee = grossCollateralAssets - collateralAssetsOut;

        // Calculate required reference assets using exchange rate (in fixed decimals).
        uint256 referenceAssetsInFixed = MathHelper.calculateDepositAmountWithSwapRate(cstSharesIn, exchangeRate, true);
        referenceAssetsIn =
            TransferHelper.fixedToTokenNativeDecimalsWithCeilDiv(referenceAssetsInFixed, self.referenceDecimals);
    }

    /// @notice Simulates unwindSwap operation to preview cST shares and reference assets received.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsIn Collateral assets to simulate depositing.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return cstSharesOut cST shares that would be unlocked.
    /// @return referenceAssetsOut Reference assets that would be received.
    /// @return fee Protocol fee that would be charged.
    function previewUnwindSwap(
        State storage self,
        MarketId poolId,
        uint256 collateralAssetsIn,
        address constraintRateAdapter
    ) public view returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee) {
        // slither-disable-next-line incorrect-equality
        if (collateralAssetsIn == 0) return (0, 0, 0);
        if (_isUnwindSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        // The fee is taken directly from the collateral asset before it's even converted to cST.
        fee = MathHelper.calculateTimeDecayFee(
            PoolShare(self.shares.swap).issuedAt(),
            self.info.expiryTimestamp,
            block.timestamp,
            collateralAssetsIn,
            self.pool.unwindSwapFeePercentage
        );

        collateralAssetsIn = collateralAssetsIn - fee;
        collateralAssetsIn = TransferHelper.tokenNativeDecimalsToFixed(collateralAssetsIn, self.collateralDecimals);

        // We use deposit here because technically the user deposit Collateral Asset to the Cork Pool when unwinding, except with swap rate applied.
        referenceAssetsOut = MathHelper.calculateDepositAmountWithSwapRate(
            collateralAssetsIn, _getLatestApplicableRate(poolId, constraintRateAdapter), false
        );
        referenceAssetsOut = TransferHelper.fixedToTokenNativeDecimals(referenceAssetsOut, self.referenceDecimals);
        cstSharesOut = collateralAssetsIn;
    }

    /// @notice Simulates unwindExercise operation to preview collateral cost and reference received.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesOut Amount of cST shares to simulate unlocking.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsIn Amount of collateral assets that would be required.
    /// @return fee Protocol fee that would be charged.
    /// @return referenceAssetsOut Amount of reference assets that would be unlocked.
    function previewUnwindExercise(
        State storage self,
        MarketId poolId,
        uint256 cstSharesOut,
        address constraintRateAdapter
    ) public view returns (uint256 collateralAssetsIn, uint256 fee, uint256 referenceAssetsOut) {
        // slither-disable-next-line incorrect-equality
        if (cstSharesOut == 0) return (0, 0, 0);
        if (_isUnwindSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        {
            uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

            referenceAssetsOut = TransferHelper.fixedToTokenNativeDecimals(
                MathHelper.calculateDepositAmountWithSwapRate(cstSharesOut, _swapRate, false), self.referenceDecimals
            );
        }

        uint256 collateralAssetsInWithoutFee =
            TransferHelper.fixedToTokenNativeDecimalsWithCeilDiv(cstSharesOut, self.collateralDecimals);

        (fee, collateralAssetsIn) = MathHelper.calculateGrossAmountWithTimeDecayFee(
            PoolShare(self.shares.swap).issuedAt(),
            self.info.expiryTimestamp,
            block.timestamp,
            collateralAssetsInWithoutFee,
            self.pool.unwindSwapFeePercentage
        );
    }

    /// @notice Simulates unwindExerciseOther operation to preview collateral cost and cST shares received.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsOut Amount of reference assets to simulate unlocking.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsIn Amount of collateral assets that would be required.
    /// @return fee Protocol fee that would be charged.
    /// @return cstSharesOut Amount of cST shares that would be unlocked.
    function previewUnwindExerciseOther(
        State storage self,
        MarketId poolId,
        uint256 referenceAssetsOut,
        address constraintRateAdapter
    ) public view returns (uint256 collateralAssetsIn, uint256 fee, uint256 cstSharesOut) {
        // slither-disable-next-line incorrect-equality
        if (referenceAssetsOut == 0) return (0, 0, 0);
        if (_isUnwindSwapPaused(self)) return (0, 0, 0);
        if (_isExpired(self)) return (0, 0, 0);

        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

        cstSharesOut = MathHelper.calculateEqualSwapAmount(
            TransferHelper.tokenNativeDecimalsToFixed(referenceAssetsOut, self.referenceDecimals), _swapRate
        );

        uint256 normalizedReferenceAsset = TransferHelper.normalizeDecimalsWithCeilDiv(
            referenceAssetsOut, self.referenceDecimals, self.collateralDecimals
        );
        uint256 assetsInWithoutFee = Math.mulDiv(normalizedReferenceAsset, _swapRate, 1e18, Math.Rounding.Ceil);

        (fee, collateralAssetsIn) = MathHelper.calculateGrossAmountWithTimeDecayFee(
            PoolShare(self.shares.swap).issuedAt(),
            self.info.expiryTimestamp,
            block.timestamp,
            assetsInWithoutFee,
            self.pool.unwindSwapFeePercentage
        );
    }

    ///======================================================///
    ///================= MAX FUNCTIONS ======================///
    ///======================================================///

    /// @notice Returns maximum cST shares that can be exercised without causing a revert.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @param owner Address to check balances and limits for.
    /// @return cstSharesIn Maximum cST shares that can be exercised.
    function maxExercise(State storage self, MarketId poolId, address owner, address constraintRateAdapter)
        external
        view
        returns (uint256 cstSharesIn)
    {
        Shares storage tokens = self.shares;

        // Get owner's cST and reference asset balances.
        uint256 ownerCstSharesBalance = IERC20(tokens.swap).balanceOf(owner);
        uint256 ownerReferenceAssetsBalance = IERC20(self.info.referenceAsset).balanceOf(owner);

        // slither-disable-next-line incorrect-equality
        if (ownerCstSharesBalance == 0 || ownerReferenceAssetsBalance == 0) return 0;

        // Check how much reference asset is required for the cST shares.
        (, uint256 referenceAssetsRequired,) =
            previewExercise(self, poolId, ownerCstSharesBalance, constraintRateAdapter);

        // If user doesn't have enough reference assets, calculate max shares they can afford.
        if (referenceAssetsRequired > ownerReferenceAssetsBalance) {
            // Find the max cST shares based on available reference assets.
            // We use previewExerciseOther to find how much cST is needed for the available reference assets.
            (, uint256 cstSharesNeeded,) =
                previewExerciseOther(self, poolId, ownerReferenceAssetsBalance, constraintRateAdapter);

            cstSharesIn = cstSharesNeeded < ownerCstSharesBalance ? cstSharesNeeded : ownerCstSharesBalance;
        } else {
            cstSharesIn = ownerCstSharesBalance;
        }
    }

    /// @notice Returns maximum reference assets that can be used in exerciseOther without causing a revert.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check balances and limits for.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return referenceAssetsIn Maximum reference assets that can be used in exerciseOther.
    function maxExerciseOther(State storage self, MarketId poolId, address owner, address constraintRateAdapter)
        external
        view
        returns (uint256 referenceAssetsIn)
    {
        Shares storage tokens = self.shares;

        uint256 ownerCstSharesBalance = IERC20(tokens.swap).balanceOf(owner);
        uint256 ownerReferenceAssetsBalance = IERC20(self.info.referenceAsset).balanceOf(owner);

        // slither-disable-next-line incorrect-equality
        if (ownerCstSharesBalance == 0 || ownerReferenceAssetsBalance == 0) return 0;

        uint8 referenceDecimals = self.referenceDecimals;
        uint8 collateralDecimals = self.collateralDecimals;

        // maxRef = pool collateral balance / rate.
        // We need to cast the collateral to ref decimals. this will determine the upperbound of the accepted reference asset.
        uint256 maxReferenceAssetsAccepted = TransferHelper.normalizeDecimals(
                self.pool.balances.collateralAsset.locked, collateralDecimals, referenceDecimals
            ) * 1e18 / _getLatestApplicableRate(poolId, constraintRateAdapter);

        referenceAssetsIn = ownerReferenceAssetsBalance < maxReferenceAssetsAccepted
            ? ownerReferenceAssetsBalance
            : maxReferenceAssetsAccepted;

        (, uint256 cstSharesRequired,) = previewExerciseOther(self, poolId, referenceAssetsIn, constraintRateAdapter);

        // Owner has enough cST to cover the whole cost, return.
        if (cstSharesRequired < ownerCstSharesBalance) {
            return referenceAssetsIn;
        }
        // Find the optimal reference asset amount.
        else {
            uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);

            referenceAssetsIn = TransferHelper.fixedToTokenNativeDecimals(
                MathHelper.calculateDepositAmountWithSwapRate(ownerCstSharesBalance, _swapRate, false),
                self.referenceDecimals
            );
        }
    }

    /// @notice Returns maximum cST shares that can be unlocked through unwindExercise.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return cstSharesOut Maximum cST shares that could be unlocked.
    function maxUnwindExercise(State storage self, MarketId poolId, address constraintRateAdapter)
        external
        view
        returns (uint256 cstSharesOut)
    {
        // The maximum cST shares is limited by the available cST balance in the pool.
        uint256 availableCstSharesBalance = self.pool.balances.swapTokenBalance;
        if (availableCstSharesBalance == 0) return 0;

        // Also limited by available reference asset balance for compensation.
        uint256 availableReferenceAssets = self.pool.balances.referenceAssetBalance;
        if (availableReferenceAssets == 0) return 0;

        // Get current swap rate.
        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);
        if (_swapRate == 0) return 0;

        uint256 referenceAssetsFixed =
            MathHelper.calculateDepositAmountWithSwapRate(availableCstSharesBalance, _swapRate, false);
        uint256 referenceAssets =
            TransferHelper.fixedToTokenNativeDecimals(referenceAssetsFixed, self.referenceDecimals);

        // If Reference Asset balance is insufficient, calculate max cST shares based on available Reference Asset.
        if (referenceAssets > availableReferenceAssets) {
            // cstShares = (availableReferenceAssets * swapRate) / 1e18.
            referenceAssetsFixed =
                TransferHelper.tokenNativeDecimalsToFixed(availableReferenceAssets, self.referenceDecimals);
            cstSharesOut = MathHelper.calculateEqualSwapAmount(referenceAssetsFixed, _swapRate);
        } else {
            cstSharesOut = availableCstSharesBalance;
        }
    }

    /// @notice Returns maximum reference assets that can be unlocked through unwindExerciseOther.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return referenceAssetsOut Maximum reference assets that could be unlocked.
    function maxUnwindExerciseOther(State storage self, MarketId poolId, address constraintRateAdapter)
        external
        view
        returns (uint256 referenceAssetsOut)
    {
        // The maximum reference assets is limited by the available reference assets balance in the pool.
        uint256 availableReferenceAssetsBalance = self.pool.balances.referenceAssetBalance;
        if (availableReferenceAssetsBalance == 0) return 0;

        // Also limited by available cST balance.
        uint256 availableCstSharesBalance = self.pool.balances.swapTokenBalance;
        if (availableCstSharesBalance == 0) return 0;

        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);
        if (_swapRate == 0) return 0;

        // Here we compute how much cST would be necessary to exercise all available reference assets locked in the pool.
        uint256 availableReferenceAssetsFixed =
            TransferHelper.tokenNativeDecimalsToFixed(availableReferenceAssetsBalance, self.referenceDecimals);
        uint256 cstSharesRequired = MathHelper.calculateEqualSwapAmount(availableReferenceAssetsFixed, _swapRate);

        // If cST balance is insufficient, calculate max reference assets based on available cST.
        if (cstSharesRequired > availableCstSharesBalance) {
            // maxReferenceAssetsFixed = (availableCstSharesBalance * 1e18) / swapRate.
            uint256 maxReferenceAssetsFixed =
                MathHelper.calculateDepositAmountWithSwapRate(availableCstSharesBalance, _swapRate, false);
            referenceAssetsOut =
                TransferHelper.fixedToTokenNativeDecimals(maxReferenceAssetsFixed, self.referenceDecimals);
        } else {
            referenceAssetsOut = availableReferenceAssetsBalance;
        }
    }

    /// @notice Returns maximum collateral assets that can be received through swap without causing a revert.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check balances and limits for.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsOut Maximum collateral amount that can be unlocked through swap.
    function maxSwap(State storage self, MarketId poolId, address owner, address constraintRateAdapter)
        external
        view
        returns (uint256 collateralAssetsOut)
    {
        Shares storage tokens = self.shares;

        // Get owner's cST and reference asset balances.
        uint256 ownerCstSharesBalance = IERC20(tokens.swap).balanceOf(owner);
        uint256 ownerReferenceAssetsBalance = IERC20(self.info.referenceAsset).balanceOf(owner);

        // Must have both cST shares and reference assets to swap.
        // slither-disable-next-line incorrect-equality
        if (ownerCstSharesBalance == 0 || ownerReferenceAssetsBalance == 0) return 0;

        // Calculate the maximum cST shares we can use based on available reference assets.
        uint256 cstSharesSpent;
        (collateralAssetsOut, cstSharesSpent,) =
            previewExerciseOther(self, poolId, ownerReferenceAssetsBalance, constraintRateAdapter);
        uint256 effectiveCstShares = ownerCstSharesBalance < cstSharesSpent ? ownerCstSharesBalance : cstSharesSpent;

        // If no effective shares, can't swap.
        // slither-disable-next-line incorrect-equality
        if (effectiveCstShares == 0) return 0;

        (collateralAssetsOut,,) = previewExercise(self, poolId, effectiveCstShares, constraintRateAdapter);
    }

    /// @notice Returns maximum collateral assets that can be deposited through unwindSwap.
    /// @param self The state of the pool.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return collateralAssetsIn Maximum collateral amount that can be deposited through unwindSwap.
    function maxUnwindSwap(State storage self, MarketId poolId, address constraintRateAdapter)
        external
        view
        returns (uint256 collateralAssetsIn)
    {
        // Get available reference asset and swap token balances in the pool.
        uint256 availableReferenceAssetsBalance = self.pool.balances.referenceAssetBalance;
        uint256 availableCstSharesBalance = self.pool.balances.swapTokenBalance;

        // If no available assets to unwind swap, return 0.
        if (availableReferenceAssetsBalance == 0 || availableCstSharesBalance == 0) return 0;

        // Get current swap rate.
        uint256 _swapRate = _getLatestApplicableRate(poolId, constraintRateAdapter);
        if (_swapRate == 0) return 0;

        uint256 maxNetCollateralAssets;

        {
            // Calculate maximum net collateral assets based on pool constraints.
            // Convert available reference assets to fixed decimals.
            uint256 availableReferenceAssetsFixed =
                TransferHelper.tokenNativeDecimalsToFixed(availableReferenceAssetsBalance, self.referenceDecimals);

            // Calculate max net collateral assets based on reference asset limit.
            uint256 maxNetFromReferenceAssets =
                MathHelper.calculateEqualSwapAmount(availableReferenceAssetsFixed, _swapRate);

            // Calculate max net collateral assets based on cST shares limit (1:1 in fixed decimals).
            uint256 maxNetFromCstShares = availableCstSharesBalance;

            // Take the minimum of the two constraints.
            uint256 maxNetCollateralAssetsFixed =
                maxNetFromReferenceAssets < maxNetFromCstShares ? maxNetFromReferenceAssets : maxNetFromCstShares;

            // Convert to collateral asset decimals.
            maxNetCollateralAssets =
                TransferHelper.fixedToTokenNativeDecimals(maxNetCollateralAssetsFixed, self.collateralDecimals);
        }

        // Use the inverse calculation from MathHelper.calculateGrossAmountWithTimeDecayFee
        // The fee function calculates: grossAmount = netAmount / (1 - effectiveFeeRate).
        // slither-disable-next-line unused-return
        (, collateralAssetsIn) = MathHelper.calculateGrossAmountWithTimeDecayFee(
            PoolShare(self.shares.swap).issuedAt(),
            self.info.expiryTimestamp,
            block.timestamp,
            maxNetCollateralAssets,
            self.pool.unwindSwapFeePercentage
        );
    }

    ///======================================================///
    ///============= RATE & FEE RELATED FUNCTIONS ===========///
    ///======================================================///

    /// @notice Updates the swap fee percentage for the specified market.
    /// @param self The state of the pool.
    /// @param newFees New swap fee percentage with 18 decimal precision (e.g., 1% = 1e18).
    function updateSwapFeePercentage(State storage self, uint256 newFees) external {
        require(newFees <= MAX_ALLOWED_FEES, IErrors.InvalidFees());
        self.pool.swapFeePercentage = newFees;
    }

    /// @notice Returns the current unwind swap fee percentage for the specified market.
    /// @param self The state of the pool.
    /// @return rate Current unwind swap fee percentage.
    function unwindSwapFeePercentage(State storage self) external view returns (uint256 rate) {
        rate = self.pool.unwindSwapFeePercentage;
    }

    /// @notice Updates the unwind swap fee percentage for the specified market.
    /// @param self The state of the pool.
    /// @param newFees New unwind swap fee percentage with 18 decimal precision (e.g., 1% = 1e18).
    function updateUnwindSwapFeePercentage(State storage self, uint256 newFees) external {
        require(newFees <= MAX_ALLOWED_FEES, IErrors.InvalidFees());
        self.pool.unwindSwapFeePercentage = newFees;
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @notice Returns the market expiry timestamp.
    /// @param self The state of the pool.
    /// @return expiry The market expiry timestamp.
    function nextExpiry(State storage self) external view returns (uint256 expiry) {
        expiry = self.info.expiryTimestamp;
    }

    /// @notice Returns true if the pool is initialized.
    /// @param self The state of the pool.
    /// @return status True if the pool is initialized.
    function isInitialized(State storage self) public view returns (bool status) {
        status = self.info.referenceAsset != address(0) && self.info.collateralAsset != address(0);
    }

    /// @notice Returns the current swap rate for the specified market.
    /// @param poolId The Cork pool identifier.
    /// @param constraintRateAdapter The address of the constraint rate adapter.
    /// @return rate Current swap rate.
    function swapRate(MarketId poolId, address constraintRateAdapter) external view returns (uint256 rate) {
        rate = _getLatestApplicableRate(poolId, constraintRateAdapter);
    }

    ///======================================================///
    ///============== INTERNAL UTILITY FUNCTIONS ============///
    ///======================================================///

    /// @dev Either collateralAssetsOut or referenceAssetsOut must be zero, but not both.
    function _previewWithdraw(State storage self, uint256 collateralAssetsOut, uint256 referenceAssetsOut)
        internal
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        if (_isWithdrawalPaused(self)) return (0, 0, 0);
        if (!_isExpired(self)) return (0, 0, 0);

        Shares storage tokens = self.shares;

        // Check if liquidity has been separated for this Swap Token.
        if (!self.pool.liquiditySeparated) {
            // If not separated, we need to simulate the separation to get accurate preview.
            uint256 availableCollateralAsset = self.pool.balances.collateralAsset.locked;
            uint256 availableReferenceAsset = self.pool.balances.referenceAssetBalance;

            cptSharesIn = _calcWithdrawAmount(
                collateralAssetsOut,
                referenceAssetsOut,
                IERC20(tokens.principal).totalSupply(),
                availableCollateralAsset,
                availableReferenceAsset
            );
        } else {
            // Liquidity already separated, use archived values.
            CorkPoolPoolArchive storage archive = self.pool.poolArchive;

            cptSharesIn = _calcWithdrawAmount(
                collateralAssetsOut,
                referenceAssetsOut,
                IERC20(tokens.principal).totalSupply(),
                archive.collateralAssetAccrued,
                archive.referenceAssetAccrued
            );
        }

        (actualReferenceAssetsOut, actualCollateralAssetsOut) = previewRedeem(self, cptSharesIn);
    }

    function _getPreviewExerciseFeeAndCollateralAssetsOut(State storage self, uint256 swapTokenProvided)
        internal
        view
        returns (uint256 collateralAssetsOut, uint256 fee)
    {
        // Calculate collateral asset output (same calculation for both modes).
        uint256 assetsBeforeFee = TransferHelper.fixedToTokenNativeDecimals(swapTokenProvided, self.collateralDecimals);

        // Calculate fee and final collateral assets amount.
        fee = MathHelper.calculatePercentageFee(self.pool.swapFeePercentage, assetsBeforeFee);
        collateralAssetsOut = assetsBeforeFee - fee;
    }

    function _getLatestApplicableRate(MarketId poolId, address constraintRateAdapter)
        internal
        view
        returns (uint256 rate)
    {
        return IConstraintRateAdapter(constraintRateAdapter).previewAdjustedRate(poolId);
    }

    // fetch and update the swap rate.
    function _getLatestApplicableRateAndUpdate(MarketId poolId, address constraintRateAdapter)
        internal
        returns (uint256 rate)
    {
        // slither-disable-next-line reentrancy-no-eth
        rate = IConstraintRateAdapter(constraintRateAdapter).adjustedRate(poolId);
    }

    function _isExpired(State storage self) internal view returns (bool) {
        // slither-disable-next-line timestamp
        return block.timestamp >= self.info.expiryTimestamp;
    }

    function _safeBeforeExpired(State storage self) internal view {
        // slither-disable-next-line timestamp
        require(block.timestamp < self.info.expiryTimestamp, IErrors.Expired());
    }

    function _safeAfterExpired(State storage self) internal view {
        // slither-disable-next-line timestamp
        require(block.timestamp >= self.info.expiryTimestamp, IErrors.NotExpired());
    }

    function _calcWithdrawAmount(
        uint256 collateralAssetsOut,
        uint256 referenceAssetsOut,
        uint256 cptTotalSupply,
        uint256 availableCollateralAsset,
        uint256 availableReferenceAsset
    ) internal pure returns (uint256 sharesIn) {
        // Calculate required shares based on which asset is being withdrawn.
        if (collateralAssetsOut > 0) {
            sharesIn = MathHelper.calculateSharesNeeded(collateralAssetsOut, availableCollateralAsset, cptTotalSupply);
        } else {
            sharesIn = MathHelper.calculateSharesNeeded(referenceAssetsOut, availableReferenceAsset, cptTotalSupply);
        }
    }

    function _calcSwapAmount(
        uint256 cptSharesIn,
        uint256 cptTotalSupply,
        uint256 availableCollateralAsset,
        uint256 availableReferenceAsset
    ) internal pure returns (uint256 accruedReferenceAsset, uint256 accruedCollateralAsset) {
        accruedReferenceAsset = MathHelper.calculateAccrued(cptSharesIn, availableReferenceAsset, cptTotalSupply);
        accruedCollateralAsset = MathHelper.calculateAccrued(cptSharesIn, availableCollateralAsset, cptTotalSupply);
    }

    function _isDepositPaused(State storage self) internal view returns (bool) {
        return (self.pool.pauseBitMap) & 1 != 0;
    }

    function _isSwapPaused(State storage self) internal view returns (bool) {
        return (self.pool.pauseBitMap) & (1 << 1) != 0;
    }

    function _isWithdrawalPaused(State storage self) internal view returns (bool) {
        return (self.pool.pauseBitMap) & (1 << 2) != 0;
    }

    function _isUnwindDepositPaused(State storage self) internal view returns (bool) {
        return (self.pool.pauseBitMap) & (1 << 3) != 0;
    }

    function _isUnwindSwapPaused(State storage self) internal view returns (bool) {
        return (self.pool.pauseBitMap) & (1 << 4) != 0;
    }
}
