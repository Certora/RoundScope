// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IErrors} from "contracts/interfaces/IErrors.sol";

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

/// @notice The market id of a pool. Will be used in most functions to specify the pool to interact.
/// @dev Calculated by hashing the `Market` struct : keccak256(abi.encode(Market)).
type MarketId is bytes32;

/// @notice Struct containing a full info about a pool.
struct Market {
    address collateralAsset; /// The pool collateral asset address.
    address referenceAsset; /// The pool reference asset address.
    uint256 expiryTimestamp; /// Pool expiry in unix epoch timestamp in seconds.
    uint256 rateMin; /// Lower limit of rate that can be returned by `rateOracle`. it will be clamped to this value if the rate returned goes below this.
    uint256 rateMax; /// Upper limit of rate that can be returned by `rateOracle`. it will be clamped to this value if the rate returned goes above this.
    uint256 rateChangePerDayMax; /// Maximum rate change allowance per day in absolute value. dictates how much the rate can change in a day.
    uint256 rateChangeCapacityMax; /// Maximum accumulated rate change allowed from rateChangePerDayMax. Every rate change will be capped at this value even If `rateChangePerDayMax` is larger than this.
    address rateOracle; /// The rate oracle address that would return the fundamental rates between the collateral and reference assets. The rates would be processed further by the constraint rate adapter using above constraints`.
}

/// @title IPoolManager
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Complete interface for CorkPoolManager contract including all core,
///         swap/exercise functionality, and market management capabilities.
interface IPoolManager is IErrors {
    // ========================================
    // EVENTS
    // ========================================

    // Core Pool Events

    /// @param poolId The Cork Pool id.
    /// @param sender The sender address.
    /// @param owner The owner/receiver of shares.
    /// @param amount0 The collateral asset amount.
    /// @param amount1 The reference asset amount.
    /// @param isRemove The assets removed or added (false when added, true when removed).
    event PoolModifyLiquidity(
        MarketId indexed poolId,
        address indexed sender,
        address indexed owner,
        uint256 amount0,
        uint256 amount1,
        bool isRemove
    );

    /// @notice Emitted when a user swaps a Swap Token for a given Cork Pool.
    /// @param poolId The Cork Pool id.
    /// @param sender The address of the sender.
    /// @param owner The address of the owner.
    /// @param amount0 The amount of the collateral asset removed after fees.
    /// @param amount1 The amount of the reference asset added after fees.
    /// @param lpFeeAmount0 Collateral asset fee earned by cPT holders, and accounted separately from the pool (zero).
    /// @param lpFeeAmount1  Reference asset fee earned by cPT holders, and accounted separately from the pool (zero).
    /// @param isUnwind Whether the swap is a repurchase (true if unwind or false when swap).
    event PoolSwap(
        MarketId indexed poolId,
        address indexed sender,
        address indexed owner,
        uint256 amount0,
        uint256 amount1,
        uint256 lpFeeAmount0,
        uint256 lpFeeAmount1,
        bool isUnwind
    );

    /// @notice Emitted when a user swaps a Swap Token for a given Cork Pool.
    /// @param poolId The Cork Pool id.
    /// @param sender The address of the sender.
    /// @param devFeeAmountInCollateralAsset The amount of the collateral asset fee to cork protocol.
    /// @param devFeeAmountInReferenceAsset The amount of the reference asset fee to cork protocol.
    /// @param isUnwind Indicating that the event emitted during swap/exercise or unwindSwap/unwindExercise.
    event PoolFee(
        MarketId indexed poolId,
        address indexed sender,
        uint256 devFeeAmountInCollateralAsset,
        uint256 devFeeAmountInReferenceAsset,
        bool isUnwind
    );

    // Market Management Events

    /// @notice Emitted when a new LV and Cork Pool is initialized with a given pair.
    /// @param poolId The Cork Pool id.
    /// @param referenceAsset The address of the reference asset.
    /// @param collateralAsset The address of the collateral asset.
    /// @param expiry The expiry interval of the Swap Token.
    event MarketCreated(
        MarketId indexed poolId,
        address indexed referenceAsset,
        address indexed collateralAsset,
        uint256 expiry,
        address rateOracle,
        address principalToken,
        address swapToken
    );

    /// @notice Emitted when one or more market actions are paused or unpaused.
    /// @dev Each bit in `pausedAction` represents the pause state of a specific market action.
    /// @dev The mapping of bit positions to actions is as follows:
    /// @dev  - Bit 0 → Deposit (`isDepositPaused`)
    /// @dev  - Bit 1 → Swap (`isSwapPaused`)
    /// @dev  - Bit 2 → Withdrawal (`isWithdrawalPaused`)
    /// @dev  - Bit 3 → Unwind deposit (`isUnwindDepositPaused`)
    /// @dev  - Bit 4 → Unwind swap (`isUnwindSwapPaused`)
    /// @param marketId The unique identifier of the market.
    /// @param pausedAction A bitmap representing the pause state of each market action.
    ///        Use `1` to indicate *paused* and `0` to indicate *unpaused* for each corresponding bit.
    event MarketActionPausedUpdate(MarketId indexed marketId, uint16 pausedAction);

    // Fee & Configuration Events.
    /// @notice Emitted when swapFeePercentage is updated.
    /// @param poolId The Cork Pool id.
    /// @param swapFeePercentage The new swapFeePercentage.
    event SwapFeePercentageUpdated(MarketId indexed poolId, uint256 indexed swapFeePercentage);

    /// @notice Emitted when an unwindSwapFee is updated for a given Cork Pool.
    /// @param poolId The Cork Pool id.
    /// @param unwindSwapFeePercentage The new unwindSwap fee.
    event UnwindSwapFeePercentageUpdated(MarketId indexed poolId, uint256 indexed unwindSwapFeePercentage);

    /// @notice Emitted when a treasury is set.
    /// @param treasury Address of treasury contract/address.
    event TreasurySet(address treasury);

    /// @notice Emitted when a shares factory is updated.
    /// @param sharesFactory Address of shares factory contract.
    event SharesFactorySet(address sharesFactory);

    // ========================================
    // DEPOSIT
    // ========================================

    /// @notice Deposits collateral assets to mint equal amounts of shares (cST & cPT shares).
    /// @dev Mints cST shares and cPT shares at 1:1 ratio after normalizing collateral to 18 decimals.
    ///      Collateral is locked in the pool and can later be withdrawn through various mechanisms.
    ///      Both share types are minted to the same receiver address with identical amounts.
    /// @param poolId The unique market identifier for the Cork Pool.
    /// @param collateralAssetsIn Amount of collateral asset to deposit (collateral asset decimals).
    /// @param receiver Address that will receive the minted cST shares and cPT shares.
    /// @return cptAndCstSharesOut Equal amounts of cST shares and cPT shares minted (always in 18 decimals).
    /// @custom:example deposit(poolId, 1000e6, alice) with USDC deposits 1000 USDC, mints 1000e18 cST & cPT shares to alice.
    /// @custom:reverts If collateralAssetsIn is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If protocol or deposit operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    function deposit(MarketId poolId, uint256 collateralAssetsIn, address receiver)
        external
        returns (uint256 cptAndCstSharesOut);

    /// @notice Simulates deposit operation to preview minted share amounts without executing.
    /// @dev Returns the exact amount of cST shares and cPT shares that would be minted for a given collateral deposit.
    ///      Mints cST shares and cPT shares at 1:1 ratio after normalizing collateral to 18 decimals.
    ///      Uses same conversion logic as deposit().
    /// @dev Returns 0 if deposits are paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsIn Amount of collateral asset to simulate depositing (native collateral decimals).
    /// @return cptAndCstSharesOut Amount of cST shares and cPT shares that would be minted (18 decimals).
    /// @custom:reverts If market has not been initialized.
    function previewDeposit(MarketId poolId, uint256 collateralAssetsIn)
        external
        view
        returns (uint256 cptAndCstSharesOut);

    /// @notice Returns maximum collateral that can be deposited in a single transaction to mint shares.
    /// @dev Mints cST shares and cPT shares at 1:1 ratio after normalizing collateral to 18 decimals.
    ///      Returns 0 if deposits are paused or market has expired, otherwise returns type(uint256).max
    ///      since there are no deposit caps in the current implementation. The owner parameter is
    ///      included for ERC4626 compatibility but currently unused in limit calculations.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check deposit limits for (currently unused but required for interface compatibility).
    /// @return maxCollateralAssetsIn Maximum collateral amount that can be deposited.
    /// @custom:reverts If market has not been initialized.
    function maxDeposit(MarketId poolId, address owner) external view returns (uint256 maxCollateralAssetsIn);

    // ========================================
    // UNWIND DEPOSIT
    // ========================================

    /// @notice Burns equal amounts of shares (cST & cPT shares) to receive exact collateral amount.
    /// @dev Reverse operation of deposit() - burns cST shares and cPT shares at 1:1 ratio to unlock collateral.
    ///      Requires equal cST shares and cPT shares ownership from the same owner. Uses floor division
    ///      to convert collateral back to 18-decimal shares.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Exact amount of collateral asset to receive (native collateral decimals).
    /// @param owner Address that owns the cST shares and cPT shares to be burned (must have sufficient balance).
    /// @param receiver Address that will receive the withdrawn collateral assets.
    /// @return cptAndCstSharesIn Amount of cST shares and cPT shares burned (equal amounts, 18 decimals).
    /// @custom:example unwindDeposit(poolId, 500e6, alice, bob) burns 500e18 cST & cPT shares from alice, sends 500 USDC to bob.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If unwind deposit operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If calculated cptAndCstSharesIn is 0.
    /// @custom:reverts If cptAndCstSharesIn is below minimum threshold(to provide at least 1 wei of shares) for the collateral token decimals.
    /// @custom:reverts If owner has insufficient cST shares or cPT shares balance/allowance.
    /// @dev When msg.sender != owner, this function uses special allowance-based transfers for cST & cPT tokens
    function unwindDeposit(MarketId poolId, uint256 collateralAssetsOut, address owner, address receiver)
        external
        returns (uint256 cptAndCstSharesIn);

    /// @notice Simulates unwind deposit operation to preview required share burn amounts.
    /// @dev Returns exact amount of cST shares and cPT shares that would need to be burned for desired collateral.
    ///      Burns cST shares and cPT shares at 1:1 ratio to unlock collateral. Uses floor division
    ///      to convert collateral back to 18-decimal shares. Uses same conversion logic as unwindDeposit(),
    ///      including minimum threshold validation.
    ///      Returns 0 if unwind deposits are paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Desired amount of collateral asset to receive (native collateral decimals).
    /// @return cptAndCstSharesIn Amount of cST shares and cPT shares that would be burned (equal amounts, 18 decimals).
    /// @custom:reverts If market has not been initialized.
    function previewUnwindDeposit(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptAndCstSharesIn);

    /// @notice Returns maximum collateral that can be withdrawn through unwind deposit by burning shares.
    /// @dev Burns cST shares and cPT shares at 1:1 ratio to unlock collateral. Calculates the maximum based on the minimum of owner's cST shares and cPT shares balances,
    ///      since equal amounts of both share types are required. Returns 0 if unwind deposits are
    ///      paused or market has expired. Uses 1:1 conversion rate from shares to collateral.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check cST shares and cPT shares balances for.
    /// @return collateralAssetsOut Maximum collateral amount that can be withdrawn (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function maxUnwindDeposit(MarketId poolId, address owner) external view returns (uint256 collateralAssetsOut);

    // ========================================
    // MINT
    // ========================================

    /// @notice Mints exact amounts of shares (cST & cPT shares) by depositing calculated collateral.
    /// @dev Reverse of deposit() - specify desired share amounts, calculates required collateral using.
    ///      ceiling division to ensure sufficient collateral for exact share amounts.
    /// @param poolId The market identifier.
    /// @param cptAndCstSharesOut Desired amount of cST shares and cPT shares to mint (18 decimals).
    /// @param receiver Address that will receive the minted cST shares and cPT shares.
    /// @return collateralAssetsIn Actual collateral amount spent (calculated with ceiling division).
    /// @custom:example mint(poolId, 1000e18, alice) mints exactly 1000 cST & cPT shares to alice.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If protocol or deposit operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If calculated collateralAssetsIn is 0.
    function mint(MarketId poolId, uint256 cptAndCstSharesOut, address receiver)
        external
        returns (uint256 collateralAssetsIn);

    /// @notice Simulates mint operation to preview required collateral amount.
    /// @dev Uses ceiling division like mint() to calculate exact collateral requirement for desired share amounts.
    ///      Returns 0 if minting is paused or market has expired. Uses same conversion logic as mint().
    /// @param poolId The Cork pool identifier.
    /// @param cptAndCstSharesOut Desired amount of cST shares and cPT shares to mint (18 decimals).
    /// @return collateralAssetsIn Collateral amount that would be required (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function previewMint(MarketId poolId, uint256 cptAndCstSharesOut) external view returns (uint256 collateralAssetsIn);

    /// @notice Returns maximum shares that can be minted in a single transaction.
    /// @dev Returns 0 if minting is paused or market has expired, otherwise returns type(uint256).max
    ///      since there are no minting caps in the current implementation. The owner parameter is
    ///      included for ERC4626 compatibility but currently unused in limit calculations.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check mint limits for (currently unused but required for interface compatibility).
    /// @return maxCptAndCstSharesOut Maximum cST shares and cPT shares that can be minted (18 decimals).
    /// @custom:reverts If market has not been initialized.
    function maxMint(MarketId poolId, address owner) external view returns (uint256 maxCptAndCstSharesOut);

    // ========================================
    // UNWIND MINT
    // ========================================

    /// @notice Burns specified amounts of shares (cST & cPT shares) to receive calculated collateral amount.
    /// @dev Reverse operation of mint() - specify exact share amounts to burn, calculates collateral returned.
    ///      Uses floor division to convert 18-decimal shares back to native collateral decimals.
    ///      Requires equal amounts of cST shares and cPT shares from the same owner.
    /// @param poolId The Cork pool identifier.
    /// @param cptAndCstSharesIn Amount of cST shares and cPT shares to burn (equal amounts, 18 decimals).
    /// @param owner Address that owns the cST shares and cPT shares to be burned (must have sufficient balance).
    /// @param receiver Address that will receive the calculated collateral assets.
    /// @return collateralAssetsOut Actual collateral amount received (calculated with floor division, native collateral decimals).
    /// @custom:example unwindMint(poolId, 750e18, alice, bob) burns 750 cST & cPT shares from alice, sends ~750 USDC to bob.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If unwind deposit operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If cptAndCstSharesIn is 0.
    /// @custom:reverts If owner has insufficient cST shares or cPT shares balance.
    /// @dev When msg.sender != owner, this function executes cST & cPT token burns on behalf of owner using allowance-based transfers
    function unwindMint(MarketId poolId, uint256 cptAndCstSharesIn, address owner, address receiver)
        external
        returns (uint256 collateralAssetsOut);

    /// @notice Simulates unwind mint operation to preview collateral amount received.
    /// @dev Returns exact amount of collateral that would be received for specified share burn amounts.
    ///      Uses floor division like unwindMint() to calculate collateral from 18-decimal shares.
    ///      Returns 0 if unwind minting is paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param cptAndCstSharesIn Amount of cST shares and cPT shares to simulate burning (18 decimals).
    /// @return collateralAssetsOut Collateral amount that would be received (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function previewUnwindMint(MarketId poolId, uint256 cptAndCstSharesIn)
        external
        view
        returns (uint256 collateralAssetsOut);

    /// @notice Returns maximum shares that can be burned through unwind mint.
    /// @dev Calculates maximum based on the minimum of owner's cST shares and cPT shares balances,
    ///      since equal amounts of both share types are required. Returns 0 if unwind minting is paused
    ///      or market has expired. Result represents equal amounts of both share types.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check cST shares and cPT shares balances for.
    /// @return maxCptAndCstSharesIn Maximum share amounts that can be burned (equal cST & cPT shares, 18 decimals).
    /// @custom:reverts If market has not been initialized.
    function maxUnwindMint(MarketId poolId, address owner) external view returns (uint256 maxCptAndCstSharesIn);

    // ========================================
    // WITHDRAW
    // ========================================

    struct WithdrawParams {
        MarketId poolId; // The Cork Pool id.
        uint256 collateralAssetsOut; // The amount of collateral asset to withdraw.
        uint256 referenceAssetsOut; // The amount of reference asset to withdraw.
        address owner; // The address that owns the Principal Token to be burned.
        address receiver; // The address that will receive the collateral assets and reference assets.
    }

    /// @notice Burns cPT shares from owner to withdraw exact collateral amount plus proportional reference assets.
    /// @dev Burns minimum required cPT shares to provide exact collateral withdrawal. Also withdraws
    ///      proportional amount of reference assets based on pool composition. Works only on active
    ///      markets (before expiry). Calculates required cPT shares amount based on current pool balances.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Exact amount of collateral asset to withdraw (native collateral decimals).
    /// @param owner Address that owns the cPT shares to be burned (must have sufficient balance).
    /// @param receiver Address that will receive both collateral and reference assets.
    /// @return cptSharesIn Amount of cPT shares burned to facilitate the withdrawal.
    /// @return actualCollateralAssetsOut Actual collateral amount received (should match input).
    /// @return actualReferenceAssetsOut Proportional reference asset amount received.
    /// @custom:example withdraw(poolId, 100e6, alice, bob) burns cPT shares from alice, sends 100 USDC + proportional ETH to bob (assuming sufficient pool balances).
    /// @custom:reverts If collateralAssetsOut is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If withdrawal operations are paused.
    /// @custom:reverts If owner has insufficient cPT shares balance/allowance.
    /// @custom:reverts If market is not expired
    /// @dev When msg.sender != owner, this function executes cPT token burns on behalf of owner using allowance-based transfers
    function withdraw(MarketId poolId, uint256 collateralAssetsOut, address owner, address receiver)
        external
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);

    /// @notice Burns cPT shares from owner to withdraw exact reference amount plus proportional collateral assets.
    /// @dev Burns minimum required cPT shares to provide exact reference asset withdrawal. Also withdraws
    ///      proportional amount of collateral assets based on pool composition. Works only on active
    ///      markets (before expiry). Calculates required cPT shares amount based on current pool balances.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsOut Exact amount of reference asset to withdraw (native reference decimals).
    /// @param owner Address that owns the cPT shares to be burned (must have sufficient balance).
    /// @param receiver Address that will receive both reference and collateral assets.
    /// @return cptSharesIn Amount of cPT shares burned to facilitate the withdrawal.
    /// @return actualCollateralAssetsOut Proportional collateral asset amount received.
    /// @return actualReferenceAssetsOut Actual reference amount received (should match input).
    /// @custom:example withdrawOther(poolId, 2e18, alice, bob) burns cPT shares from alice, sends 2 ETH + proportional USDC to bob (assuming sufficient pool balances).
    /// @custom:reverts If referenceAssetsOut is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If withdrawal operations are paused.
    /// @custom:reverts If owner has insufficient cPT shares balance/allowance.
    /// @custom:reverts If market is not expired
    /// @dev When msg.sender != owner, this function executes cPT token burns on behalf of owner using allowance-based transfers
    function withdrawOther(MarketId poolId, uint256 referenceAssetsOut, address owner, address receiver)
        external
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);

    /// @notice Simulates withdraw operation to preview required cPT shares burn and asset amounts received.
    /// @dev Returns exact cPT shares amount needed to withdraw specified collateral, plus the proportional
    ///      reference asset amount that would also be withdrawn. Burns minimum required cPT shares to provide exact collateral withdrawal. Also withdraws
    ///      proportional amount of reference assets based on pool composition. Calculates required cPT shares amount based on current pool balances.
    ///      Uses current pool balances for calculation. Returns zeros if withdrawal is paused or invalid conditions exist.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Desired amount of collateral asset to withdraw (native collateral decimals).
    /// @return cptSharesIn cPT shares that would need to be burned.
    /// @return actualCollateralAssetsOut Collateral amount that would be withdrawn.
    /// @return actualReferenceAssetsOut Proportional reference asset amount that would be withdrawn.
    /// @custom:reverts If market has not been initialized.
    function previewWithdraw(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);

    /// @notice Simulates withdrawOther operation to preview required cPT shares burn and asset amounts received.
    /// @dev Returns exact cPT shares amount needed to withdraw specified reference asset, plus the proportional
    ///      collateral amount that would also be withdrawn. Burns minimum required cPT shares to provide exact reference asset withdrawal. Also withdraws
    ///      proportional amount of collateral assets based on pool composition. Calculates required cPT shares amount based on current pool balances.
    ///      Uses current pool balances for calculation. Returns zeros if withdrawal is paused or invalid conditions exist.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsOut Desired amount of reference asset to withdraw (native reference decimals).
    /// @return cptSharesIn cPT shares that would need to be burned.
    /// @return actualCollateralAssetsOut Proportional collateral amount that would be withdrawn.
    /// @return actualReferenceAssetsOut Reference amount that would be withdrawn.
    /// @custom:reverts If market has not been initialized.
    function previewWithdrawOther(MarketId poolId, uint256 referenceAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut);

    /// @notice Returns maximum collateral assets that can be withdrawn through withdraw function.
    /// @dev Calculates maximum based on owner's cPT shares balance and current pool composition.
    ///      Returns 0 if withdrawals are paused or market has expired. Uses owner's full
    ///      cPT shares balance to determine maximum withdrawable collateral amount.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check cPT shares balance for.
    /// @return maxCollateralAssetsOut Maximum collateral amount that can be withdrawn (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function maxWithdraw(MarketId poolId, address owner) external view returns (uint256 maxCollateralAssetsOut);

    /// @notice Returns maximum reference assets that can be withdrawn through withdrawOther function.
    /// @dev Calculates maximum based on owner's cPT shares balance and current pool composition.
    ///      Returns 0 if withdrawals are paused or market has expired. Uses owner's full
    ///      cPT shares balance to determine maximum withdrawable reference asset amount.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check cPT shares balance for.
    /// @return maxReferenceAssetsOut Maximum reference amount that can be withdrawn (native reference decimals).
    /// @custom:reverts If market has not been initialized.
    function maxWithdrawOther(MarketId poolId, address owner) external view returns (uint256 maxReferenceAssetsOut);

    // ========================================
    // REDEEM
    // ========================================

    /// @notice Burns cPT shares after market expiry to receive proportional share of both asset pools.
    /// @dev Only works AFTER market expiry. Burns cPT shares to receive proportional amounts of both
    ///      collateral and reference assets based on the burned cPT shares vs total cPT shares supply ratio.
    ///      First redemption triggers liquidity separation, archiving current pool balances.
    ///      Subsequent redemptions draw from archived liquidity pools.
    /// @param poolId The Cork pool identifier.
    /// @param cptSharesIn Amount of cPT shares to burn (18 decimals).
    /// @param owner Address that owns the cPT shares to be burned (must have sufficient balance).
    /// @param receiver Address that will receive both asset types.
    /// @return referenceAssetsOut Proportional reference asset amount received (native reference decimals).
    /// @return collateralAssetsOut Proportional collateral asset amount received (native collateral decimals).
    /// @custom:example redeem(poolId, 100e18, alice, bob) after expiry burns 100 cPT shares from alice, sends proportional ETH+USDC to bob.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If withdrawal operations are paused.
    /// @custom:reverts If current time < market expiry timestamp.
    /// @custom:reverts If cptSharesIn is 0.
    /// @custom:reverts If cptSharesIn is below minimum threshold for asset decimals.
    /// @custom:reverts If owner has insufficient cPT shares balance.
    /// @dev When msg.sender != owner, this function executes cPT token burns on behalf of owner using allowance-based transfers
    function redeem(MarketId poolId, uint256 cptSharesIn, address owner, address receiver)
        external
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut);

    /// @notice Simulates redeem operation to preview asset amounts that would be received.
    /// @dev Returns proportional amounts of both assets that would be received for specified cPT shares burn.
    ///      Burns cPT shares to receive proportional amounts of both collateral and reference assets based on
    ///      the burned cPT shares vs total cPT shares supply ratio. First redemption triggers liquidity separation,
    ///      archiving current pool balances. Subsequent redemptions draw from archived liquidity pools.
    ///      Calculation uses current or archived pool balances depending on whether liquidity has been
    ///      separated. Returns zeros if redemption is paused or market hasn't expired yet.
    /// @param poolId The Cork pool identifier.
    /// @param cptSharesIn Amount of cPT shares to simulate burning (18 decimals).
    /// @return referenceAssetsOut Reference asset amount that would be received (native reference decimals).
    /// @return collateralAssetsOut Collateral asset amount that would be received (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function previewRedeem(MarketId poolId, uint256 cptSharesIn)
        external
        view
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut);

    /// @notice Returns maximum cPT shares that can be redeemed without causing a revert.
    /// @dev Returns owner's full cPT shares balance if market has expired and redemption is not paused,
    ///      otherwise returns 0. Ensures the returned amount will not exceed actual maximum
    ///      that would be accepted by the redeem function. Factors in pause status and expiry.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check cPT shares balance for.
    /// @return maxCptSharesIn Maximum cPT shares that can be redeemed (18 decimals).
    /// @custom:reverts If market has not been initialized.
    function maxRedeem(MarketId poolId, address owner) external view returns (uint256 maxCptSharesIn);

    // ========================================
    // EXERCISE
    // ========================================

    struct ExerciseParams {
        MarketId poolId; // The Cork Pool id.
        address receiver; // The address that will receive the collateral assets.
        uint256 collateralAssetsOut; // The amount of collateral assets to receive.
        uint256 cstSharesIn; // The amount of cST shares to lock (must be 0 if compensation is non-zero).
        uint256 referenceAssetsIn; // The amount of reference token compensation to lock (must be 0 if shares is non-zero).
        uint256 fee; // The amount of collateral assets fee
    }

    /// @notice Exercises cST shares to receive collateral assets at current market swap rate.
    /// @dev Locks cST shares + reference asset (not burned) based on the current swap rate. Calculates collateral payout based on current swap rate,
    ///      rate constraints, and available liquidity.
    ///      All tokens(cST shares, reference assets) become pool liquidity that can be obtained through unwindExercise/unwindSwap(if market is not expired).
    ///      At expiry, the cPT holders can claim all the reference & collateral assets left in the pool. distributed pro-rate.
    /// @dev Protocol fees are charged.
    /// @dev Works only on active markets before expiry.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesIn Amount of cST shares to exercise and lock (18 decimals, must be > 0).
    /// @param receiver Address that will receive the calculated collateral assets.
    /// @return collateralAssetsOut Collateral amount received based on swap rate calculation (native collateral decimals).
    /// @return referenceAssetsIn Additional reference asset payment required from caller (native reference decimals).
    /// @return fee Protocol fee charged on the operation. In collateral assets (sent to treasury)
    /// @custom:example exercise(poolId, 50e18, alice) locks 50 cST shares + additional ETH payment based on the current swap rate, sends USDC to alice.
    /// @custom:reverts If cstSharesIn is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If swap operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If caller has insufficient cST shares or reference asset balance.
    /// @custom:reverts If exercise would violate rate constraints.
    function exercise(MarketId poolId, uint256 cstSharesIn, address receiver)
        external
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Exercises using reference assets to receive collateral at current market swap rate
    /// @dev Uses reference asset payment to calculate collateral payout and required cST shares lock amount.
    ///      Locks cST shares + reference asset (not burned) based on the current swap rate. Calculates collateral payout based on current swap rate,
    ///      rate constraints, and available liquidity.
    ///      All tokens(cST shares, reference assets) become pool liquidity that can be obtained through unwindExercise/unwindSwap(if market is not expired).
    ///      At expiry, the cPT holders can claim all the reference & collateral assets left in the pool. distributed pro-rate.
    /// @dev Protocol fees are charged.
    /// @dev Works only on active markets before expiry.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsIn Amount of reference asset to provide as payment (native reference decimals, must be > 0).
    /// @param receiver Address that will receive the calculated collateral assets.
    /// @return collateralAssetsOut Collateral amount received based on swap rate calculation (native collateral decimals).
    /// @return cstSharesIn cST shares required to be locked from caller (18 decimals).
    /// @return fee Protocol fee charged on the operation. In collateral assets (sent to treasury)
    /// @custom:example exerciseOther(poolId, 1e18, alice) pays 1 ETH, locks calculated cST shares, sends USDC to alice.
    /// @custom:reverts If referenceAssetsIn is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If swap operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If caller has insufficient cST shares or reference asset balance.
    /// @custom:reverts If exercise would violate rate constraints.
    function exerciseOther(MarketId poolId, uint256 referenceAssetsIn, address receiver)
        external
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee);

    /// @notice Simulates exercise operation to preview collateral received and costs.
    /// @dev Returns exact amounts that would result from exercising specified cST shares.
    ///      Locks cST shares + reference asset (not burned) based on the current swap rate. Calculates collateral payout based on current swap rate,
    ///      rate constraints, and available liquidity. Includes collateral payout, any additional reference asset payment required,
    ///      and protocol fees. Calculation uses current swap rates and constraints.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesIn Amount of cST shares to simulate exercising (18 decimals).
    /// @return collateralAssetsOut Collateral amount that would be received (native collateral decimals).
    /// @return referenceAssetsIn Additional reference payment that would be required (native reference decimals).
    /// @return fee Protocol fee that would be charged. In collateral assets.
    /// @custom:reverts If market has not been initialized.
    function previewExercise(MarketId poolId, uint256 cstSharesIn)
        external
        view
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Simulates exerciseOther operation to preview collateral received and cST shares requirements
    /// @dev Returns exact amounts that would result from exercising with specified reference asset payment.
    ///      Uses reference asset payment to calculate collateral payout and required cST shares lock amount.
    ///      Locks cST shares + reference asset (not burned) based on the current swap rate. Calculates collateral payout based on current swap rate,
    ///      rate constraints, and available liquidity. Includes collateral payout, cST shares required to be locked, and protocol fees.
    ///      Calculation uses current swap rates and constraints.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsIn Amount of reference asset to simulate providing (native reference decimals).
    /// @return collateralAssetsOut Collateral amount that would be received (native collateral decimals).
    /// @return cstSharesIn cST shares that would need to be locked (18 decimals).
    /// @return fee Protocol fee that would be charged.
    /// @custom:reverts If market has not been initialized.
    function previewExerciseOther(MarketId poolId, uint256 referenceAssetsIn)
        external
        view
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee);

    /// @notice Returns maximum cST shares that can be exercised without causing a revert.
    /// @dev Calculates maximum based on owner's cST shares and reference asset balances, current swap rates,
    ///      rate constraints, and available pool liquidity. Considers both user limits and global
    ///      constraints. Returns 0 if exercise is paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check balances and limits for.
    /// @return maxCstSharesIn Maximum cST shares that can be exercised (18 decimals).
    /// @custom:reverts If market has not been initialized.
    function maxExercise(MarketId poolId, address owner) external view returns (uint256 maxCstSharesIn);

    /// @notice Returns maximum reference assets that can be used in exerciseOther without causing a revert.
    /// @dev Calculates maximum based on owner's reference asset and cST balances, current swap rates,
    ///      rate constraints, and available pool liquidity. Considers both user limits and global
    ///      constraints. Returns 0 if exercise is paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check balances and limits for.
    /// @return maxReferenceAssetsIn Maximum reference assets that can be used in exerciseOther (native reference decimals).
    /// @custom:reverts If market has not been initialized.
    function maxExerciseOther(MarketId poolId, address owner) external view returns (uint256 maxReferenceAssetsIn);

    // ========================================
    // UNWIND EXERCISE
    // ========================================

    struct UnwindExerciseParams {
        MarketId poolId;
        address receiver;
        uint256 cstSharesOut;
        uint256 referenceAssetsOut;
        uint256 collateralAssetsIn;
        uint256 fee;
    }

    /// @notice Deposits collateral to unlock specific amount of previously exercised cST shares.
    /// @dev Reverse operation of exercise() - deposits collateral to unlock cST shares and
    ///      associated reference asset compensation from previous exercise operations. Calculates
    ///      required collateral and received reference assets + cST shares based on current swap rates and constraints. Protocol fees apply.
    ///      Helps restore liquidity and allows users to exit exercise positions.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesOut Amount of cST shares to unlock and receive (18 decimals, must be > 0).
    /// @param receiver Address that will receive the unlocked cST shares and reference assets.
    /// @return collateralAssetsIn Collateral amount required to be deposited by caller (native collateral decimals).
    /// @return referenceAssetsOut Reference asset compensation unlocked and sent to receiver (native reference decimals).
    /// @return fee Protocol fee charged on the operation (sent to treasury).
    /// @custom:example unwindExercise(poolId, 25e18, alice) deposits USDC, unlocks 25 cST shares + ETH compensation to alice.
    /// @custom:reverts If cstSharesOut is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If unwind swap operations are paused.
    /// @custom:reverts If caller has insufficient collateral asset balance.
    /// @custom:reverts If not enough locked cST shares available to unlock.
    function unwindExercise(MarketId poolId, uint256 cstSharesOut, address receiver)
        external
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Deposits collateral to unlock specific amount of previously locked reference assets.
    /// @dev Reverse operation of exerciseOther() - deposits collateral to unlock reference asset
    ///      compensation and associated cST shares from previous exercise operations. Calculates
    ///      required collateral and cST shares amounts based on current swap rates and constraints.
    ///      Protocol fees apply. Helps restore liquidity and exit exercise positions.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsOut Amount of reference assets to unlock and receive (native reference decimals, must be > 0).
    /// @param receiver Address that will receive the unlocked reference assets and cST shares.
    /// @return collateralAssetsIn Collateral amount required to be deposited by caller (native collateral decimals).
    /// @return cstSharesOut cST shares unlocked and sent to receiver (18 decimals).
    /// @return fee Protocol fee charged on the operation (sent to treasury).
    /// @custom:example unwindExerciseOther(poolId, 0.5e18, alice) deposits USDC, unlocks 0.5 ETH + cST shares to alice
    /// @custom:reverts If referenceAssetsOut is 0.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If unwind swap operations are paused.
    /// @custom:reverts If caller has insufficient collateral asset balance.
    /// @custom:reverts If not enough locked reference assets available to unlock.
    function unwindExerciseOther(MarketId poolId, uint256 referenceAssetsOut, address receiver)
        external
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee);

    /// @notice Simulates unwindExercise operation to preview collateral cost and reference received.
    /// @dev Returns exact amounts required and received for unlocking specified cST shares.
    ///      Deposits collateral to unlock cST shares and associated reference asset compensation from previous exercise operations. Calculates
    ///      required collateral and received reference assets + cST shares based on current swap rates and constraints.
    ///      Includes collateral cost, reference asset compensation unlocked, and protocol fees.
    ///      Calculation uses current swap rates, constraints, and available locked positions.
    /// @param poolId The Cork pool identifier.
    /// @param cstSharesOut Amount of cST shares to simulate unlocking (18 decimals).
    /// @return collateralAssetsIn Collateral amount that would be required (native collateral decimals).
    /// @return referenceAssetsOut Reference compensation that would be unlocked (native reference decimals).
    /// @return fee Protocol fee that would be charged.
    /// @custom:reverts If market has not been initialized.
    function previewUnwindExercise(MarketId poolId, uint256 cstSharesOut)
        external
        view
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Simulates unwindExerciseOther operation to preview collateral cost and cST shares received.
    /// @dev Returns exact amounts required and received for unlocking specified reference assets.
    ///      Deposits collateral to unlock reference asset compensation and associated cST shares from previous exercise operations. Calculates
    ///      required collateral and cST shares amounts based on current swap rates and constraints.
    ///      Includes collateral cost, cST shares unlocked, and protocol fees. Calculation uses
    ///      current swap rates, constraints, and available locked positions.
    /// @param poolId The Cork pool identifier.
    /// @param referenceAssetsOut Amount of reference assets to simulate unlocking (native reference decimals).
    /// @return collateralAssetsIn Collateral amount that would be required (native collateral decimals).
    /// @return cstSharesOut cST shares that would be unlocked (18 decimals).
    /// @return fee Protocol fee that would be charged.
    /// @custom:reverts If market has not been initialized.
    function previewUnwindExerciseOther(MarketId poolId, uint256 referenceAssetsOut)
        external
        view
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee);

    /// @notice Returns maximum cST shares that can be unlocked through unwindExercise.
    /// @dev Calculates maximum based on available locked cST shares positions in the pool, not user balance.
    ///      Assumes caller has infinite collateral assets to pay the required amounts. Returns 0
    ///      if unwind operations are paused. Does not factor in user's collateral balance.
    /// @param poolId The Cork pool identifier.
    /// @return maxCstSharesOut Maximum cST shares that could be unlocked (18 decimals).
    /// @custom:reverts If market has not been initialized.
    function maxUnwindExercise(MarketId poolId, address) external view returns (uint256 maxCstSharesOut);

    /// @notice Returns maximum reference assets that can be unlocked through unwindExerciseOther.
    /// @dev Calculates maximum based on available locked reference asset positions in the pool, not user balance.
    ///      Assumes caller has infinite collateral assets to pay the required amounts. Returns 0
    ///      if unwind operations are paused. Does not factor in user's collateral balance.
    /// @param poolId The Cork pool identifier.
    /// @return maxReferenceAssetsOut Maximum reference assets that could be unlocked (native reference decimals).
    /// @custom:reverts If market has not been initialized.
    function maxUnwindExerciseOther(MarketId poolId, address) external view returns (uint256 maxReferenceAssetsOut);

    // ========================================
    // SWAP
    // ========================================

    /// @notice Locks cST shares and reference assets to receive exact amount of collateral assets.
    /// @dev Calculates required cST shares and reference assets to provide exact collateral output.
    ///      cST shares + reference assets are locked (not burned)
    ///      All tokens(cST shares, reference assets) become pool liquidity that can be obtained through unwindExercise/unwindSwap(if market is not expired).
    ///      At expiry, the cPT holders can claim all the reference & collateral assets left in the pool. distributed pro-rate.
    /// @dev Uses current swap rates and constraints to determine payment amounts. Protocol fees apply.
    ///      Works only on active markets before expiry.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Exact amount of collateral assets to receive (native collateral decimals).
    /// @param receiver Address that will receive the specified collateral assets.
    /// @return cstSharesIn cST shares required to be locked from caller (18 decimals).
    /// @return referenceAssetsIn Reference assets required as payment from caller (native reference decimals).
    /// @return fee Protocol fee charged on the operation (sent to treasury).
    /// @custom:example swap(poolId, 200e6, alice) locks cST shares + pays ETH from caller, sends exactly 200 USDC to alice.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If swap operations are paused.
    /// @custom:reverts If current time >= market expiry timestamp.
    /// @custom:reverts If caller has insufficient cST shares or reference asset balance.
    /// @custom:reverts If swap would violate rate constraints.
    /// @custom:reverts If insufficient pool liquidity available.
    function swap(MarketId poolId, uint256 collateralAssetsOut, address receiver)
        external
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Simulates swap operation to preview required cST shares and reference asset payments.
    /// @dev Returns exact payment amounts required to receive specified collateral output.
    ///      Calculates required cST shares and reference assets to provide exact collateral output.
    ///      cST shares + reference assets are locked (not burned). Uses current swap rates and constraints to determine collateral payment amounts.
    ///      Includes cST shares to lock, reference assets to pay, and protocol fees.
    ///      Calculation uses current swap rates, constraints, and pool liquidity.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsOut Amount of collateral assets to simulate receiving (native collateral decimals).
    /// @return cstSharesIn cST shares that would need to be locked (18 decimals).
    /// @return referenceAssetsIn Reference assets that would need to be paid (native reference decimals).
    /// @return fee Protocol fee that would be charged.
    /// @custom:reverts If market has not been initialized.
    function previewSwap(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee);

    /// @notice Returns maximum collateral assets that can be received through swap without causing a revert.
    /// @dev Calculates maximum based on owner's cST shares and reference asset balances, current swap rates,
    ///      rate constraints, and available pool liquidity. Uses optimal balance logic - determines
    ///      maximum effective cST shares usable based on reference asset capacity, then finds minimum with
    ///      actual cST shares balance. Returns 0 if swaps are paused or market has expired.
    /// @param poolId The Cork pool identifier.
    /// @param owner Address to check balances and limits for.
    /// @return maxCollateralAssetsOut Maximum collateral amount that can be received through swap (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function maxSwap(MarketId poolId, address owner) external view returns (uint256 maxCollateralAssetsOut);

    // ========================================
    // UNWIND SWAP
    // ========================================

    /// @notice Deposits collateral assets to unlock cST shares and receive reference asset compensation.
    /// @dev Reverse operation of swap() - deposits collateral to unlock previously locked cST shares + reference assets.
    ///      That is calculated on current swap rates and current rate constraint.
    /// @dev Protocol fees apply.
    ///      Helps restore liquidity and allows users to exit swap positions.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsIn Amount of collateral assets to deposit (native collateral decimals).
    /// @param receiver Address that will receive the unlocked cST shares and reference assets.
    /// @return cstSharesOut cST shares unlocked and sent to receiver (18 decimals).
    /// @return referenceAssetsOut Reference asset compensation sent to receiver (native reference decimals).
    /// @return fee Protocol fee charged on the operation (sent to treasury).
    /// @custom:example unwindSwap(poolId, 150e6, alice) deposits 150 USDC, unlocks cST shares + ETH compensation to alice.
    /// @custom:reverts If market has not been initialized.
    /// @custom:reverts If unwind swap operations are paused.
    /// @custom:reverts If caller has insufficient collateral asset balance.
    /// @custom:reverts If not enough locked positions available to unlock.
    function unwindSwap(MarketId poolId, uint256 collateralAssetsIn, address receiver)
        external
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Simulates unwindSwap operation to preview cST shares and reference assets received.
    /// @dev Returns exact amounts that would be unlocked for specified collateral deposit.
    ///      Deposits collateral to unlock previously locked cST shares + reference assets
    ///      that is calculated on current swap rates and current rate constraint. Includes cST shares unlocked, reference asset compensation, and protocol fees.
    ///      Calculation uses current swap rates, constraints, and available locked positions.
    /// @param poolId The Cork pool identifier.
    /// @param collateralAssetsIn Amount of collateral assets to simulate depositing (native collateral decimals).
    /// @return cstSharesOut cST shares that would be unlocked (18 decimals).
    /// @return referenceAssetsOut Reference asset compensation that would be received (native reference decimals).
    /// @return fee Protocol fee that would be charged.
    /// @custom:reverts If market has not been initialized.
    function previewUnwindSwap(MarketId poolId, uint256 collateralAssetsIn)
        external
        view
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee);

    /// @notice Returns maximum collateral assets that can be deposited through unwindSwap.
    /// @dev Calculates maximum based on available locked swap positions in the pool, not user balance.
    ///      Assumes caller has infinite collateral assets to deposit. Returns 0 if unwind swap
    ///      operations are paused. Does not factor in user's collateral balance - focuses on
    ///      global pool limits and available positions to unlock.
    /// @param poolId The Cork pool identifier.
    /// @return maxCollateralAssetsIn Maximum collateral amount that can be deposited through unwindSwap (native collateral decimals).
    /// @custom:reverts If market has not been initialized.
    function maxUnwindSwap(MarketId poolId, address) external view returns (uint256 maxCollateralAssetsIn);

    // ========================================
    // MARKET INFORMATION & QUERIES
    // ========================================

    /// @notice Returns the current exchange rate between Reference Asset and Collateral Asset. This exchange rate is used in swap/exercise and unwindSwap/unwindExercise
    /// @dev The rate represents the value of 1 Reference Asset quoted in Collateral Asset (REFCA).
    ///      A rate of 0.8e18 means 1 REF is worth 0.8 CA.
    ///
    ///      Exercise/swap formula: nCA = nREF × rate, nCST = nREF × rate
    ///
    ///      Examples with rate = 0.8e18:
    ///      - Exercising 1 REF + 0.8 CST yields 0.8 CA
    ///      - To receive 1 CA, exercise 1.25 REF + 1 CST (since 1 ÷ 0.8 = 1.25)
    /// @param poolId The Cork pool identifier.
    /// @return rate Current exchange rate scaled by 1e18 (1 = 1e18).
    /// @custom:reverts If market has not been initialized.
    function swapRate(MarketId poolId) external view returns (uint256 rate);

    /// @notice Returns the total value locked (TVL) of both asset types in the Cork Pool.
    /// @param poolId The Cork pool identifier.
    /// @return collateralAssets Total collateral assets locked in the pool (native collateral decimals).
    /// @return referenceAssets Total reference assets locked in the pool (native reference decimals).
    /// @custom:reverts If market has not been initialized.
    function assets(MarketId poolId) external view returns (uint256 collateralAssets, uint256 referenceAssets);

    /// @notice Returns the contract addresses of cPT shares and cST shares for a given market.
    /// @param poolId The Cork pool identifier.
    /// @return principalToken Contract address of the cPT shares (Collateral Principal Token).
    /// @return swapToken Contract address of the cST shares (Cork Swap Token).
    /// @custom:reverts If market has not been initialized.
    function shares(MarketId poolId) external view returns (address principalToken, address swapToken);

    /// @notice Retrieves complete market configuration and parameters for a given market.
    /// @dev Returns the full Market struct containing all configuration details including
    ///      asset addresses, expiry timestamp, rate oracle, and rate constraints.
    /// @param poolId The market identifier.
    /// @return parameters Complete Market struct with all configuration details.
    /// @custom:reverts If market has not been initialized.
    function market(MarketId poolId) external view returns (Market memory parameters);

    /// @notice Generates a deterministic unique market identifier from market parameters.
    /// @dev Creates a MarketId by hashing all market parameters using keccak256. The same
    ///      parameters will always produce the same ID, enabling deterministic market lookups.
    ///      Used both for market creation and market identification across the protocol.
    /// @param marketParameters Complete market configuration including:
    ///        - referenceAsset: Address of the reference asset
    ///        - collateralAsset: Address of the collateral asset
    ///        - expiryTimestamp: Market expiry time in Unix timestamp(seconds)
    ///        - rateOracle: Address of the rate oracle contract
    ///        - rateMin: Minimum allowed rate constraint
    ///        - rateMax: Maximum allowed rate constraint
    ///        - rateChangePerDayMax: Daily rate change limit
    ///        - rateChangeCapacityMax: Total rate change capacity limit
    /// @return marketId Unique deterministic market identifier
    function getId(Market calldata marketParameters) external view returns (MarketId marketId);

    // ========================================
    // FEE MANAGEMENT
    // ========================================

    /// @notice Returns the current swap fee percentage for the specified market.
    /// @dev Fee applies to swap and exercise operations. Returned value uses 18 decimal precision
    ///      where 1e18 represents 1% (100 basis points). Fees are collected by the protocol treasury.
    /// @param poolId The Cork pool identifier.
    /// @return fees Current swap fee percentage with 18 decimal precision (1e18 = 1%).
    /// @custom:reverts If market has not been initialized.
    function swapFee(MarketId poolId) external view returns (uint256 fees);

    /// @notice Returns the current unwind swap fee percentage for the specified market.
    /// @dev Fee applies to unwind swap and unwind exercise operations. Returned value uses 18 decimal
    ///      precision where 1e18 represents 1% (100 basis points). Fees are collected by the protocol treasury.
    /// @param poolId The Cork pool identifier.
    /// @return fees Current unwind swap fee percentage with 18 decimal precision (1e18 = 1%).
    /// @custom:reverts If market has not been initialized.
    function unwindSwapFee(MarketId poolId) external view returns (uint256 fees);

    /// @notice Updates the swap fee percentage for the specified market.
    /// @dev Only callable by controller contract. Sets the fee percentage applied to swap and exercise
    ///      operations. Fee must be provided with 18 decimal precision (e.g., 1% = 1e18).
    /// @param poolId The Cork pool identifier.
    /// @param newSwapFeePercentage New swap fee percentage with 18 decimal precision (e.g., 1% = 1e18)
    /// @custom:reverts If caller is not the controller contract.
    /// @custom:reverts If market has not been initialized.
    function updateSwapFeePercentage(MarketId poolId, uint256 newSwapFeePercentage) external;

    /// @notice Updates the unwind swap fee percentage for the specified market.
    /// @dev Only callable by controller contract. Sets the fee percentage applied to unwind swap
    ///      and unwind exercise operations. Fee must be provided with 18 decimal precision.
    /// @param poolId The Cork pool identifier.
    /// @param newUnwindSwapFeePercentage New unwind swap fee percentage with 18 decimal precision (e.g., 1% = 1e18)
    /// @custom:reverts If caller is not the controller contract.
    /// @custom:reverts If market has not been initialized.
    function updateUnwindSwapFeePercentage(MarketId poolId, uint256 newUnwindSwapFeePercentage) external;

    // ========================================
    // MARKET MANAGEMENT & ADMINISTRATION
    // ========================================

    /// @notice Creates and initializes a new Cork Pool market with specified parameters.
    /// @dev Only callable by controller contract. Deploys new cPT shares and cST shares contracts, validates all
    ///      parameters, and initializes the market state. Validates expiry timestamp, asset addresses,
    ///      oracle configuration, and decimal constraints (<= 18 decimals). Emits MarketCreated event.
    /// @param poolParams Complete market configuration including asset addresses, expiry, oracle, and rate constraints.
    /// @custom:reverts If caller is not the controller contract.
    /// @custom:reverts If protocol is paused.
    /// @custom:reverts If market with same parameters already exists.
    /// @custom:reverts If expiry timestamp is not in the future.
    /// @custom:reverts If any asset address is zero address.
    /// @custom:reverts If reference and collateral assets are the same.
    /// @custom:reverts If rate oracle address is zero.
    /// @custom:reverts If asset decimals exceed 18.
    function createNewPool(Market calldata poolParams) external;

    /// @notice Updates the pause status for specific operations in a given market.
    /// @dev Only callable by controller contract. Uses a bitmap to efficiently control multiple
    ///      operation types with a single transaction. Each bit position controls a specific operation:
    ///      Bit 0 → Deposit operations, Bit 1 → Swap operations, Bit 2 → Withdrawal operations,
    ///      Bit 3 → Unwind deposit operations, Bit 4 → Unwind swap operations.
    ///      Emits MarketActionPausedUpdate event with the new pause state.
    /// @param marketId The unique identifier of the Cork Pool market.
    /// @param newPauseBitMap Bitmap representing pause states (1 = paused, 0 = unpaused for each bit position).
    /// @custom:reverts If caller is not the controller contract.
    /// @custom:reverts If market has not been initialized.
    function setPausedBitMap(MarketId marketId, uint16 newPauseBitMap) external;

    /// @notice Returns the current pause status bitmap for all operations in a market.
    /// @dev Returns a bitmap where each bit represents the pause state of a specific operation type.
    ///      Bit positions map to: Bit 0 → Deposit, Bit 1 → Swap, Bit 2 → Withdrawal,
    ///      Bit 3 → Unwind deposit, Bit 4 → Unwind swap. Value of 1 indicates paused, 0 indicates active.
    /// @param marketId The unique identifier of the Cork Pool market.
    /// @return pauseBitMap Current pause bitmap (1 = paused, 0 = active for each bit position).
    /// @custom:reverts If market has not been initialized.
    function getPausedBitMap(MarketId marketId) external view returns (uint16 pauseBitMap);

    /// @notice Pauses or unpauses the entire protocol across all markets.
    /// @dev Only callable by admin role. When protocol is paused, all operations across all markets
    ///      are disabled regardless of individual market pause states. This is an emergency mechanism
    ///      to halt all protocol activity when needed.
    /// @param isAllPaused True to pause entire protocol, false to unpause.
    /// @custom:reverts If caller does not have admin role.
    function setAllPaused(bool isAllPaused) external;

    /// @notice Updates the protocol treasury address where fees are sent.
    /// @dev Only callable by admin role. All protocol fees from swap, exercise, unwind operations
    ///      across all markets will be sent to this address. Emits TreasurySet event with new address.
    /// @param newTreasury New treasury address to receive protocol fees.
    /// @custom:reverts If caller does not have admin role.
    /// @custom:reverts If newTreasury is zero address.
    function setTreasuryAddress(address newTreasury) external;

    /// @notice Updates the shares factory address.
    /// @dev Only callable by admin role. The shares factory address is used to deploy new cPT and cST shares contracts.
    /// @param newSharesFactory New shares factory address.
    /// @custom:reverts If caller does not have admin role.
    /// @custom:reverts If newSharesFactory is zero address.
    function setSharesFactory(address newSharesFactory) external;
}
