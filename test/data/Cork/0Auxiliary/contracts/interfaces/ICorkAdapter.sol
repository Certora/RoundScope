// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

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

/// @title ICorkAdapter
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Interface for CorkAdapter contract
interface ICorkAdapter {
    /// @dev The contract is already initialized.
    error InvalidInitialization();

    /// @dev thrown when deadline is exceeded
    error DeadlineExceeded();

    struct SafeMintParams {
        MarketId poolId; // The cork pool market id
        uint256 cptAndCstSharesOut; // The amount of cPT and cST shares to mint.
        address receiver; // The address to which shares(cST & cPT) will be minted.
        uint256 maxCollateralAssetsIn; // The maximum amount of collateral assets to spend for minting shares.
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeDepositParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsIn; // The amount of collateral assets to deposit.
        address receiver; // The address to which shares(cST & cPT) will be minted.
        uint256 minCptAndCstSharesOut; // The minimum amount of shares(cST & cPT) to receive.
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindDepositParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsOut; // The amount of target collateral to get from the unwind.
        address owner; // The address that owns the cPT and cST shares being burned
        address receiver; // The address to which collateral assets and any excess shares will be sent.
        uint256 maxCptAndCstSharesIn; // The maximum amount of shares to burn for the unwind operation.
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindMintParams {
        MarketId poolId; // The cork pool market id
        uint256 cptAndCstSharesIn; // The amount of shares to redeem. Pass type(uint).max to redeem the owner's shares.
        address owner; // The address that owns the cPT and cST shares being burned
        address receiver; // The address to which collateral assets and any excess shares will be sent.
        uint256 minCollateralAssetsOut; // The minimum amount of collateral to receive from the unwind operation.
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeWithdrawParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsOut; // The amount of collateral asset to withdraw
        address owner; // The address that owns the cPT shares being burned
        address receiver; // The address to which withdrawn assets will be sent
        uint256 maxCptSharesIn; // The maximum amount of cPT shares to burn for the withdrawal
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeWithdrawOtherParams {
        MarketId poolId; // The cork pool market id
        uint256 referenceAssetsOut; // The amount of reference asset to withdraw
        address owner; // The address that owns the cPT shares being burned
        address receiver; // The address to which withdrawn assets will be sent
        uint256 maxCptSharesIn; // The maximum amount of cPT shares to burn for the withdrawal
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeWithdrawInternalParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsOut; // The amount of collateral asset to withdraw (set to 0 if withdrawing reference asset)
        uint256 referenceAssetsOut; // The amount of reference asset to withdraw (set to 0 if withdrawing collateral asset)
        address owner; // The address that owns the cPT shares being burned
        address receiver; // The address to which withdrawn assets will be sent
        uint256 maxCptSharesIn; // The maximum amount of cPT shares to burn for the withdrawal
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeRedeemParams {
        MarketId poolId; // The cork pool market id
        uint256 cptSharesIn; // The amount of cPT tokens to redeem. Pass `type(uint).max` to use the adapter's cPT balance/allowance.
        address owner; // The address that owns the cPT tokens being redeemed
        address receiver; // The address to which redeemed assets will be sent
        uint256 minReferenceAssetsOut; // The minimum amount of reference asset to receive
        uint256 minCollateralAssetsOut; // The minimum amount of collateral asset to receive
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindSwapParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsIn; // The amount of collateral assets to use for unwind swap. Pass `type(uint).max` to use the adapter's collateral asset balance.
        address receiver; // The address to which reference assets and swap tokens will be sent
        uint256 minReferenceAssetsOut; // The minimum amount of reference assets to receive
        uint256 minCstSharesOut; // The minimum amount of cST shares to receive
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeSwapParams {
        MarketId poolId; // The cork pool market id
        uint256 collateralAssetsOut; // The amount of collateral assets to receive
        address receiver; // The address to which collateral assets will be sent
        uint256 maxCstSharesIn; // The maximum amount of cST shares to spend for the swap
        uint256 maxReferenceAssetsIn; // The maximum amount of reference token compensation to spend for the swap
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeExerciseParams {
        MarketId poolId; // The cork pool market id
        uint256 cstSharesIn; // The amount of cST shares to lock
        address receiver; // The address to which collateral assets will be sent
        uint256 minCollateralAssetsOut; // The minimum amount of collateral assets to receive
        uint256 maxReferenceAssetsIn; // The maximum amount of reference asset that can be spent
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeExerciseOtherParams {
        MarketId poolId; // The cork pool market id
        uint256 referenceAssetsIn; // The amount of reference token compensation to lock
        address receiver; // The address to which collateral assets will be sent
        uint256 minCollateralAssetsOut; // The minimum amount of collateral assets to receive
        uint256 maxCstSharesIn; // The maximum amount of cST shares that can be spent
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeExerciseInternalParams {
        MarketId poolId; // The cork pool market id
        uint256 cstSharesIn; // The amount of cST shares to lock (set to 0 if using referenceAssets)
        uint256 referenceAssetsIn; // The amount of reference token compensation to lock (set to 0 if using cstShares)
        address receiver; // The address to which collateral assets will be sent
        uint256 minCollateralAssetsOut; // The minimum amount of collateral assets to receive
        uint256 maxOtherTokenIn; // The maximum amount of other asset that can be spent
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindExerciseParams {
        MarketId poolId; // The cork pool market id
        uint256 cstSharesOut; // The amount of cST shares to unlock (must be non-zero)
        address receiver; // The address to which unlocked cST shares and reference token compensation will be sent
        uint256 minReferenceAssetsOut; // The minimum amount of reference token compensation to receive from the unwind exercise
        uint256 maxCollateralAssetsIn; // The maximum amount of collateral assets to spend for the unwind exercise
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindExerciseOtherParams {
        MarketId poolId; // The cork pool market id
        uint256 referenceAssetsOut; // The amount of reference token to unlock (must be non-zero)
        address receiver; // The address to which unlocked cST shares and reference token compensation will be sent
        uint256 minCstSharesOut; // The minimum amount of cST shares to receive from the unwind exercise
        uint256 maxCollateralAssetsIn; // The maximum amount of collateral assets to spend for the unwind exercise
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    struct SafeUnwindExerciseInternalParams {
        MarketId poolId; // The cork pool market id
        uint256 cstSharesOut; // The amount of cST shares to unlock (must be non-zero if referenceAssetsOut is 0)
        uint256 referenceAssetsOut; // The amount of reference token to unlock (must be non-zero if cstSharesOut is 0)
        address receiver; // The address to which unlocked cST shares and reference token compensation will be sent
        uint256 minOtherAssetOut; // The minimum amount of other asset(cST shares or reference token) to receive from the unwind exercise
        uint256 maxCollateralAssetsIn; // The maximum amount of collateral assets to spend for the unwind exercise
        uint256 deadline; // The deadline by which the transaction must be completed.
    }

    /// @notice Initialize the CorkAdapter contract
    /// @dev Can only be called once. This function ensures we can deploy CorkAdapter to the same address across chains
    /// even with bundler3 having different addresses.
    /// @param ensOwner The address of the ENS owner for this contract.
    /// @param bundler3 The address of the Bundler3 contract.
    /// @param cork The address of the Cork's IPool contract.
    /// @param whitelistManager The address of the WhitelistManager contract.
    function initialize(address ensOwner, address bundler3, address cork, address whitelistManager) external;

    /// @notice Mints shares(cST & cPT) of an Cork Pool.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param params The parameters for the safe mint operation.
    /// params.poolId The cork pool market id
    /// params.cptAndCstSharesOut The amount of vault shares to mint.
    /// params.receiver The address to which shares(cST & cPT) will be minted.
    /// params.maxCollateralAssetsIn The maximum amount of collateral assets to spend for minting shares.
    /// params.deadline The deadline by which the transaction must be completed.
    function safeMint(SafeMintParams calldata params) external;

    /// @notice Deposits collateral token in a Cork Market.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @param params The parameters for the safe deposit operation.
    /// params.poolId The cork pool market id
    /// params.collateralAssetsIn The amount of collateral asset to deposit.
    /// params.receiver The address to which shares(cST & cPT) will be minted.
    /// params.minCptAndCstSharesOut The minimum amount of shares to receive from the deposit.
    /// params.deadline The deadline by which the transaction must be completed.
    function safeDeposit(SafeDepositParams calldata params) external;

    /// @notice Unwinds a deposit by burning equal amounts of cPT and cST shares.
    /// @notice if owner != adapter, then cPT tokens must have been approved to the adapter by owner.
    /// @notice if owner == adapter, then cPT tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe unwind deposit operation.
    /// params.poolId The cork pool market id
    /// params.collateralAssetsOut The amount of target collateral to get from the unwind.
    /// params.owner The address that owns the cPT and cST shares being burned. Owner MUST EITHER be the Bundler3 initiator or the CorkAdapter address.
    /// params.receiver The address to which collateral assets and any excess shares will be sent.
    /// params.maxCptAndCstSharesIn The maximum amount of shares to burn for the unwind operation.
    /// params.deadline The deadline by which the transaction must be completed.
    function safeUnwindDeposit(SafeUnwindDepositParams calldata params) external;

    /// @notice Unwinds a mint by burning equal amounts of cPT and cST shares.
    /// @notice if owner != adapter, then cPT tokens must have been approved to the adapter by owner.
    /// @notice if owner == adapter, then cPT tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe unwind mint operation.
    /// params.poolId The cork pool market id
    /// params.cptAndCstSharesIn The amount of shares to redeem. Pass type(uint).max to redeem the owner's shares.
    /// params.owner The address that owns the cPT and cST shares being burned. Owner MUST EITHER be the Bundler3 initiator or the CorkAdapter address.
    /// params.receiver The address to which collateral assets and any excess shares will be sent.
    /// params.minCollateralAssetsOut The minimum amount of collateral to receive from the unwind operation.
    /// params.deadline The deadline by which the transaction must be completed.
    function safeUnwindMint(SafeUnwindMintParams memory params) external;

    /// @notice Withdraws specific amounts of collateral assets from a Cork Pool.
    /// @notice if owner != adapter, then cPT tokens must have been approved to the adapter by owner.
    /// @notice if owner == adapter, then cPT tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe withdraw operation.
    /// params.poolId The cork pool market id
    /// params.collateralAssetsOut The amount of collateral asset to withdraw
    /// params.owner The address that owns the cPT shares being burned. Owner MUST EITHER be the Bundler3 initiator or the CorkAdapter address.
    /// params.receiver The address to which withdrawn assets will be sent
    /// params.maxCptSharesIn The maximum amount of cPT shares to burn for the withdrawal
    /// params.deadline The deadline by which the transaction must be completed
    function safeWithdraw(SafeWithdrawParams calldata params) external;

    /// @notice Withdraws specific amounts of reference assets from a Cork Pool.
    /// @notice if owner != adapter, then cPT tokens must have been approved to the adapter by owner.
    /// @notice if owner == adapter, then cPT tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe withdraw operation.
    /// params.poolId The cork pool market id
    /// params.referenceAssetsOut The amount of reference asset to withdraw
    /// params.owner The address that owns the cPT shares being burned. Owner MUST EITHER be the Bundler3 initiator or the CorkAdapter address.
    /// params.receiver The address to which withdrawn assets will be sent
    /// params.maxCptSharesIn The maximum amount of cPT shares to burn for the withdrawal
    /// params.deadline The deadline by which the transaction must be completed
    function safeWithdrawOther(SafeWithdrawOtherParams calldata params) external;

    /// @notice Redeems cPT tokens for collateral and reference assets at expiry.
    /// @notice if owner != adapter, then cPT tokens must have been approved to the adapter by owner.
    /// @notice if owner == adapter, then cPT tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe redeem operation.
    /// params.poolId The cork pool market id
    /// params.cptShares The amount of cPT tokens to redeem. Pass `type(uint).max` to use the adapter's cPT balance/allowance.
    /// params.owner The address that owns the cPT tokens being redeemed. Owner MUST EITHER be the Bundler3 initiator or the CorkAdapter address.
    /// params.receiver The address to which redeemed assets will be sent
    /// params.minReferenceAssetsOut The minimum amount of reference asset to receive
    /// params.minCollateralAssetsOut The minimum amount of collateral asset to receive
    /// params.deadline The deadline by which the transaction must be completed
    function safeRedeem(SafeRedeemParams memory params) external;

    /// @notice Unwinds a swap by using collateral assets to receive reference assets and swap tokens.
    /// @notice Collateral assets must have been previously sent to the adapter.
    /// @param params The parameters for the safe unwind swap operation.
    /// params.poolId The cork pool market id
    /// params.collateralAssetsIn The amount of collateral assets to use for unwind swap. Pass `type(uint).max` to use the adapter's collateral asset balance.
    /// params.receiver The address to which reference assets and swap tokens will be sent
    /// params.minReferenceAssetsOut The minimum amount of reference assets to receive
    /// params.minCstSharesOut The minimum amount of cST shares to receive
    /// params.deadline The deadline by which the transaction must be completed
    function safeUnwindSwap(SafeUnwindSwapParams memory params) external;

    /// @notice Swaps cST shares and reference token compensation for collateral assets.
    /// @notice cST tokens and reference tokens must have been transferred to the adapter before calling this.
    /// @param params The parameters for the safe swap operation.
    /// params.poolId The cork pool market id
    /// params.collateralAssetsOut The exact amount of collateral assets to receive
    /// params.receiver The address to which collateral assets will be sent
    /// params.maxCstSharesIn The maximum amount of cST shares to spend for the swap
    /// params.maxReferenceAssetsIn The maximum amount of reference token compensation to spend for the swap
    /// params.deadline The deadline by which the transaction must be completed
    function safeSwap(SafeSwapParams calldata params) external;

    /// @notice Exercises cST shares or reference token compensation for collateral assets.
    /// @notice cST tokens and reference tokens must have been transferred to the adapter before calling this.
    /// @notice cstShares must be non-zero.
    /// @param params The parameters for the safe exercise operation.
    /// params.poolId The cork pool market id
    /// params.cstSharesIn The amount of cST shares to lock
    /// params.receiver The address to which collateral assets will be sent
    /// params.minCollateralAssetsOut The minimum amount of collateral assets to receive
    /// params.maxReferenceAssetsIn The maximum amount of reference asset that can be spent
    /// params.deadline The deadline by which the transaction must be completed
    function safeExercise(SafeExerciseParams calldata params) external;

    /// @notice Exercises reference token compensation for collateral assets.
    /// @notice cST tokens and reference tokens must have been transferred to the adapter before calling this.
    /// @notice referenceAssets must be non-zero.
    /// @param params The parameters for the safe exercise operation.
    /// params.poolId The cork pool market id
    /// params.referenceAssetsIn The amount of reference token compensation to lock
    /// params.receiver The address to which collateral assets will be sent
    /// params.minCollateralAssetsOut The minimum amount of collateral assets to receive
    /// params.maxCstSharesIn The maximum amount of cST shares that can be spent
    /// params.deadline The deadline by which the transaction must be completed
    function safeExerciseOther(SafeExerciseOtherParams calldata params) external;

    /// @notice Unwinds an exercise by depositing collateral assets to unlock cST shares and reference token compensation.
    /// @notice Collateral assets must have been previously sent to the adapter.
    /// @param params The parameters for the safe unwind exercise operation.
    /// params.poolId The cork pool market id
    /// params.cstSharesOut The amount of cST shares to unlock.
    /// params.receiver The address to which unlocked cST shares and reference token compensation will be sent
    /// params.minReferenceAssetsOut The minimum amount of reference token compensation to receive
    /// params.maxCollateralAssetsIn The maximum amount of collateral assets to spend for the unwind exercise
    /// params.deadline The deadline by which the transaction must be completed
    function safeUnwindExercise(SafeUnwindExerciseParams calldata params) external;

    /// @notice Unwinds an exercise by depositing collateral assets to unlock cST shares and reference token compensation.
    /// @notice Collateral assets must have been previously sent to the adapter.
    /// @param params The parameters for the safe unwind exercise operation.
    /// params.poolId The cork pool market id
    /// params.referenceAssetsOut The amount of reference token to unlock.
    /// params.receiver The address to which unlocked cST shares and reference token compensation will be sent
    /// params.minCstSharesOut The minimum amount of cST shares to receive
    /// params.maxCollateralAssetsIn The maximum amount of collateral assets to spend for the unwind exercise
    /// params.deadline The deadline by which the transaction must be completed
    function safeUnwindExerciseOther(SafeUnwindExerciseOtherParams calldata params) external;
}
