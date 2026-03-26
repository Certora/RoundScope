// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IErrors} from "contracts/interfaces/IErrors.sol";
import {IPoolManager, MarketId} from "contracts/interfaces/IPoolManager.sol";

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

/// @title IPoolShare
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Interface for PoolShare contract with ERC4626-compatible events.
interface IPoolShare is IErrors {
    struct ConstructorParams {
        MarketId poolId;
        string pairName;
        string symbol;
        address poolManager;
        address ensOwner;
    }

    /// @notice Designed for topic0 compatibility with ERC4626. Emitted by cPT address
    /// @param sender msg.sender
    /// @param owner Receiver of shares.
    /// @param assets Collateral amount added.
    /// @param shares Amount of cPT or cST minted.
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    /// @notice Designed for topic0 compatibility with ERC4626. Emitted by cPT address
    /// @notice Purpose: Enables standard ERC4626 tooling and indexers to track withdrawals seamlessly.
    /// @param sender msg.sender with allowance
    /// @param receiver Receiver of withdrawn collateral assets.
    /// @param owner Owner of shares.
    /// @param assets Collateral amount removed.
    /// @param shares Amount of cPT burned.
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    /// @param sender msg.sender with allowance
    /// @param receiver Receiver of withdrawn reference assets.
    /// @param owner Owner of shares.
    /// @param asset Reference asset address.
    /// @param assets Reference asset amount removed.
    /// @param shares Amount of cPT burned.
    event WithdrawOther(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        address asset,
        uint256 assets,
        uint256 shares
    );

    /// @notice Emitted when a user deposits a reference asset for a given Cork Pool.
    /// @param sender The address of the sender.
    /// @param owner The address of the owner.
    /// @param asset The address of the reference asset.
    /// @param assets The amount of reference assets added to the pool.
    /// @param shares The amount of cPT shares minted (zero).
    event DepositOther(address indexed sender, address indexed owner, address asset, uint256 assets, uint256 shares);

    /// @notice Returns the pair name of the shares.
    /// @return The name of the asset pair.
    function pairName() external view returns (string memory);

    /// @notice Returns the pool ID for the shares.
    /// @return The pool ID for the asset contract.
    function poolId() external view returns (MarketId);

    /// @notice Returns the cork pool manager address.
    /// @return The address of the cork pool manager contract.
    function poolManager() external view returns (IPoolManager);

    /// @notice Returns the factory address.
    /// @return The address of the factory contract.
    function factory() external view returns (address);

    /// @notice Provides Collateral Assets & Reference Assets assets reserves for the shares contract.
    /// @return collateralAssets The Collateral Assets reserve amount for shares contract.
    /// @return referenceAssets The Reference Assets reserve amount for shares contract.
    function getReserves() external view returns (uint256 collateralAssets, uint256 referenceAssets);

    /// @return True if the share is expired.
    function isExpired() external view returns (bool);

    ///@return The expiry timestamp.
    function expiry() external view returns (uint256);

    ///@return The timestamp when the share was issued.
    function issuedAt() external view returns (uint256);

    /// @notice Emits a deposit event for ERC4626 compatibility.
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address initiating the deposit.
    /// @param receiver The address receiving the shares.
    /// @param assets The amount of assets deposited.
    /// @param shares The amount of shares minted.
    function emitDeposit(address sender, address receiver, uint256 assets, uint256 shares) external;

    /// @notice Emits a withdraw event for ERC4626 compatibility.
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address initiating the withdrawal.
    /// @param receiver The address receiving the assets.
    /// @param owner The address owning the shares.
    /// @param assets The amount of assets withdrawn.
    /// @param shares The amount of shares burned.
    function emitWithdraw(address sender, address receiver, address owner, uint256 assets, uint256 shares) external;

    /// @notice Emits a withdraw other event.
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address initiating the withdrawal.
    /// @param receiver The address receiving the reference assets.
    /// @param owner The address owning the shares.
    /// @param asset The address of the reference asset.
    /// @param assets The amount of reference assets withdrawn.
    /// @param shares The amount of shares burned.
    function emitWithdrawOther(
        address sender,
        address receiver,
        address owner,
        address asset,
        uint256 assets,
        uint256 shares
    ) external;

    /// @notice Emits a deposit other event.
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address initiating the deposit.
    /// @param owner The address receiving the shares.
    /// @param asset The address of the reference asset.
    /// @param assets The amount of reference assets deposited.
    /// @param shares The amount of shares minted.
    function emitDepositOther(address sender, address owner, address asset, uint256 assets, uint256 shares) external;

    /// @notice mints `amount` number of tokens to `to` address.
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param to Address of receiver.
    /// @param amount Number of tokens to be minted.
    function mint(address to, uint256 amount) external;

    /// @notice burns `amount` number of tokens from `owner` by spending the allowance that `owner` has to `sender`  .
    /// - This operation can only be done by CorkPoolManager
    /// - if sender == owner, it will treat it as a regular `burn`
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address of the sender.
    /// @param owner Address of the owner to be burned from.
    /// @param amount Number of tokens to be burned.
    function burnFrom(address sender, address owner, uint256 amount) external;

    /// @notice Transfer `amount` of token to address `to` on behalf of `owner` by spending the allowance that `owner` has to `sender`  .
    /// - This operation can only be done by CorkPoolManager
    /// @dev This function can only be called by the cork pool manager contract (owner).
    /// @param sender The address of the sender.
    /// @param owner The address of the owner.
    /// @param to The address of the receiver.
    /// @param amount The amount of tokens to transfer.
    function transferFrom(address sender, address owner, address to, uint256 amount) external;

    /// @notice Returns the maximum amount of cPT and cST tokens that can be minted.
    /// @param owner The address of the owner.
    /// @return maxCptAndCstSharesOut The maximum amount of cPT and cST tokens that can be minted.
    function maxMint(address owner) external view returns (uint256 maxCptAndCstSharesOut);

    /// @notice Returns the maximum amount of collateral asset that can be deposited.
    /// @param owner The address of the owner.
    /// @return maxCollateralAssetsIn The maximum amount of collateral asset that can be deposited.
    function maxDeposit(address owner) external view returns (uint256 maxCollateralAssetsIn);

    /// @notice Gets the maximum amount of collateral asset that can be received by unwinding deposit.
    /// @param owner The address to check balances for.
    /// @return maxCollateralAssetsOut The maximum amount of collateral asset that can be received.
    function maxUnwindDeposit(address owner) external view returns (uint256 maxCollateralAssetsOut);

    /// @notice Gets the maximum amount of cPT and cST tokens that can be burned in unwind mint.
    /// @param owner The address to check balances for.
    /// @return maxCptAndCstSharesIn The maximum amount of tokens that can be burned.
    function maxUnwindMint(address owner) external view returns (uint256 maxCptAndCstSharesIn);

    /// @notice Returns the maximum amount of assets that could be transferred from `owner` through `withdraw`.
    /// @param owner The address of the owner.
    /// @return maxCollateralAssetsOut The maximum amount of assets that could be withdrawn.
    function maxWithdraw(address owner) external view returns (uint256 maxCollateralAssetsOut);

    /// @notice Returns the maximum amount of reference assets that could be transferred from `owner` through `withdraw`.
    /// @param owner The address of the owner.
    /// @return maxReferenceAssetsOut The maximum amount of reference assets that could be withdrawn.
    function maxWithdrawOther(address owner) external view returns (uint256 maxReferenceAssetsOut);

    /// @notice Returns the maximum amount of cST shares that could be transferred from `owner` through `exercise` and not cause a revert.
    /// @param owner The address of the owner.
    /// @return maxCstSharesIn The maximum amount of cST shares that could be used in exercise.
    function maxExercise(address owner) external view returns (uint256 maxCstSharesIn);

    /// @notice Returns the maximum amount of reference assets that could be used as compensation in `exercise` and not cause a revert.
    /// @param owner The address of the owner.
    /// @return maxReferenceAssetsIn The maximum amount of reference assets that could be used as compensation in exercise.
    function maxExerciseOther(address owner) external view returns (uint256 maxReferenceAssetsIn);

    /// @notice Returns the maximum amount of cPT shares that could be transferred from `owner` through `redeem` and not cause a revert.
    /// @param owner The address of the owner.
    /// @return maxCptSharesIn The maximum amount of cPT shares that could be redeemed.
    function maxRedeem(address owner) external view returns (uint256 maxCptSharesIn);

    /// @notice Returns the maximum amount of collateral assets that could be transferred from `owner` through `swap` and not cause a revert.
    /// @param owner The address of the owner.
    /// @return maxCollateralAssetsOut The maximum amount of collateral assets that could be transferred through swap.
    function maxSwap(address owner) external view returns (uint256 maxCollateralAssetsOut);

    /// @notice Returns the maximum amount of cST shares that could be transferred through `unwindExercise` and not cause a revert.
    /// @param owner The address of the owner. (not used for calculation)
    /// @return maxCstSharesOut The maximum amount of cST shares that could be unlocked through unwindExercise.
    function maxUnwindExercise(address owner) external view returns (uint256 maxCstSharesOut);

    /// @notice Returns the maximum amount of reference assets that would be unlocked through `unwindExercise` and not cause a revert.
    /// @param owner The address of the owner. (not used for calculation)
    /// @return maxReferenceAssetsOut The maximum amount of reference assets that would be unlocked through unwindExercise.
    function maxUnwindExerciseOther(address owner) external view returns (uint256 maxReferenceAssetsOut);

    /// @notice Returns the maximum amount of assets that could be transferred through `unwindSwap` and not cause a revert.
    /// @param owner The address of the owner. (not used for calculation)
    /// @return maxCollateralAssetsIn The maximum amount of collateral assets that could be transferred through unwindSwap.
    function maxUnwindSwap(address owner) external view returns (uint256 maxCollateralAssetsIn);

    /// @notice Previews the outcome of exercising cST shares.
    /// @param cstSharesIn The amount of cST shares to exercise (must be non-zero).
    /// @return collateralAssetsOut The amount of collateral assets that would be received.
    /// @return referenceAssetsIn The amount of reference asset that would be spent.
    /// @return fee The fee amount that would be charged.
    function previewExercise(uint256 cstSharesIn)
        external
        view
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Previews the outcome of exercising cST shares.
    /// @param referenceAssetsIn The amount of reference asset compensation to provide (must be non-zero).
    /// @return collateralAssetsOut The amount of collateral assets that would be received.
    /// @return cstSharesIn The amount of other asset that would be spent.
    /// @return fee The fee amount that would be charged.
    function previewExerciseOther(uint256 referenceAssetsIn)
        external
        view
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee);

    /// @notice Previews the outcome of unwinding an exercise operation.
    /// @param cstSharesOut The amount of cST tokens to mint.
    /// @return collateralAssetsIn The amount of collateral asset that would be required.
    /// @return referenceAssetsOut The amount of reference asset compensation that would be received.
    /// @return fee The fee amount that would be charged.
    function previewUnwindExercise(uint256 cstSharesOut)
        external
        view
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Previews the outcome of unwinding an exercise operation.
    /// @param referenceAssetsOut The amount of reference token to mint.
    /// @return collateralAssetsIn The amount of collateral asset that would be required.
    /// @return cstSharesOut The amount of cST tokens that would be received.
    /// @return fee The fee amount that would be charged.
    function previewUnwindExerciseOther(uint256 referenceAssetsOut)
        external
        view
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee);

    /// @notice Previews the amount of cPT and cST tokens that would be minted for a deposit.
    /// @param collateralAssetsIn The amount of collateral asset to deposit.
    /// @return cptAndCstSharesOut The amount of cPT and cST tokens that would be minted.
    function previewDeposit(uint256 collateralAssetsIn) external view returns (uint256 cptAndCstSharesOut);

    /// @notice Previews the amount of cST shares and reference token compensation that would be required for a swap.
    /// @param collateralAssetsOut The exact amount of collateral assets that would be received.
    /// @return cstSharesIn The amount of cST shares that would be locked from msg.sender
    /// @return referenceAssetsIn The amount of reference token that would be locked from msg.sender
    /// @return fee The fee amount that would be charged.
    function previewSwap(uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Previews the amounts of assets that would be received when redeeming cPT tokens.
    /// @param cptSharesIn The amount of cPT tokens to redeem.
    /// @return referenceAssetsOut The amount of reference asset that would be received.
    /// @return collateralAssetsOut The amount of collateral asset that would be received.
    function previewRedeem(uint256 cptSharesIn)
        external
        view
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut);

    /// @notice Previews the amount of cPT and cST tokens needed to unwind deposit for specific collateral amount.
    /// @param collateralAssetsOut The desired amount of collateral asset to receive.
    /// @return cptAndCstSharesIn The amount of cPT and cST tokens that would need to be burned.
    function previewUnwindDeposit(uint256 collateralAssetsOut) external view returns (uint256 cptAndCstSharesIn);

    /// @notice Previews the outcome of unwinding a swap operation.
    /// @param collateralAssetsIn The amount of cPT tokens to unwind.
    /// @return cstSharesOut The amount of cST tokens that would be received.
    /// @return referenceAssetsOut The amount of reference asset that would be received.
    /// @return fee The fee amount that would be charged.
    function previewUnwindSwap(uint256 collateralAssetsIn)
        external
        view
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Previews the amount of collateral needed to mint specific amounts of cPT and cST tokens.
    /// @param cptAndCstSharesOut The desired amount of cPT and cST tokens to mint.
    /// @return collateralAssetsIn The amount of collateral asset that would be required.
    function previewMint(uint256 cptAndCstSharesOut) external view returns (uint256 collateralAssetsIn);

    /// @notice Previews the amount of collateral that would be received when unwinding mint.
    /// @param cptAndCstSharesIn The amount of cPT and cST tokens to burn.
    /// @return collateralAssetsOut The amount of collateral asset that would be received.
    function previewUnwindMint(uint256 cptAndCstSharesIn) external view returns (uint256 collateralAssetsOut);

    /// @notice Previews the amount of cPT tokens needed to withdraw specific amounts of assets.
    /// @param collateralAssetsOut The desired amount of collateral asset to withdraw.
    /// @return cptSharesIn The amount of cPT tokens that would need to be burned.
    /// @return actualCollateralAssetsOut The actual amount of collateral asset that would be withdrawn.
    /// @return actualReferenceAssetsOut The actual amount of reference asset that would be withdrawn.
    function previewWithdraw(uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);

    /// @notice Previews the amount of cPT tokens needed to withdraw specific amounts of assets.
    /// @param referenceAssetsOut The desired amount of reference asset to withdraw.
    /// @return cptSharesIn The amount of cPT tokens that would need to be burned.
    /// @return actualCollateralAssetsOut The actual amount of collateral asset that would be withdrawn.
    /// @return actualReferenceAssetsOut The actual amount of reference asset that would be withdrawn.
    function previewWithdrawOther(uint256 referenceAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);
}
