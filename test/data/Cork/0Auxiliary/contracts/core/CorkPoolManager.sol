// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CorkPoolManagerStorage} from "contracts/core/CorkPoolManagerStorage.sol";
import {IPoolManager, Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {IPoolShare} from "contracts/interfaces/IPoolShare.sol";
import {ISharesFactory} from "contracts/interfaces/ISharesFactory.sol";
import {IWhitelistManager} from "contracts/interfaces/IWhitelistManager.sol";
import {PoolLibrary} from "contracts/libraries/PoolLib.sol";
import {CorkPoolPoolArchive, State} from "contracts/libraries/State.sol";
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

/// @title CorkPoolManager
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice CorkPoolManager contract provides Cork Pool related logic.
contract CorkPoolManager is
    IPoolManager,
    CorkPoolManagerStorage,
    PausableUpgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable
{
    using PoolLibrary for State;
    using SafeERC20 for IERC20;

    bytes32 public constant CORK_CONTROLLER_ROLE = keccak256("CORK_CONTROLLER_ROLE");

    ///======================================================///
    ///============== INITIALIZATION FUNCTIONS ==============///
    ///======================================================///

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer function for upgradeable contracts
    function initialize(
        address ensOwner,
        address admin,
        address constraintRateAdapter,
        address treasury,
        address whitelistManager
    ) external initializer {
        require(ensOwner != address(0), InvalidParams());
        require(admin != address(0), InvalidParams());
        require(constraintRateAdapter != address(0), InvalidParams());
        require(treasury != address(0), InvalidParams());
        require(whitelistManager != address(0), InvalidParams());

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __Ownable_init(ensOwner);

        // Initial cork pool manager owner.
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        initializeCorkPoolManagerStorage(constraintRateAdapter, treasury, whitelistManager);
    }

    ///======================================================///
    ///================ MARKET RELATED FUNCTIONS ============///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function createNewPool(Market calldata poolParams) external override nonReentrant whenNotPaused {
        _onlyCorkController();

        uint8 referenceDecimals = IERC20Metadata(poolParams.referenceAsset).decimals();
        uint8 collateralDecimals = IERC20Metadata(poolParams.collateralAsset).decimals();

        // slither-disable-next-line timestamp
        require(poolParams.expiryTimestamp > block.timestamp, InvalidExpiry());
        require(poolParams.referenceAsset != address(0), ZeroAddress());
        require(poolParams.collateralAsset != address(0), ZeroAddress());
        require(poolParams.referenceAsset != poolParams.collateralAsset, InvalidAddress());
        require(poolParams.rateOracle != address(0), ZeroAddress());
        require(collateralDecimals <= 18, InvalidParams());
        require(referenceDecimals <= 18, InvalidParams());
        require(poolParams.rateMin > 0, InvalidParams());
        require(poolParams.rateMin < poolParams.rateMax, InvalidParams());

        MarketId poolId = MarketId.wrap(keccak256(abi.encode(poolParams)));

        State storage state = data().states[poolId];

        require(!state.isInitialized(), AlreadyInitialized());

        // slither-disable-next-line reentrancy-no-eth
        state.initialize(poolId, poolParams, data().CONSTRAINT_ADAPTER);

        (address principalToken, address swapToken) = ISharesFactory(data().SHARES_FACTORY)
            .deployPoolShares(ISharesFactory.DeployParams({poolParams: poolParams, poolId: poolId}));

        state.shares.swap = swapToken;
        state.shares.principal = principalToken;
        state.referenceDecimals = referenceDecimals;
        state.collateralDecimals = collateralDecimals;

        emit MarketCreated(
            poolId,
            poolParams.referenceAsset,
            poolParams.collateralAsset,
            poolParams.expiryTimestamp,
            poolParams.rateOracle,
            principalToken,
            swapToken
        );
    }

    /// @inheritdoc IPoolManager
    function getId(Market calldata marketParameters) external pure returns (MarketId) {
        return MarketId.wrap(keccak256(abi.encode(marketParameters)));
    }

    /// @inheritdoc IPoolManager
    function market(MarketId poolId) external view returns (Market memory parameters) {
        parameters = data().states[poolId].info;
    }

    ///======================================================///
    ///================ DEPOSIT FUNCTIONS ===================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function deposit(MarketId poolId, uint256 collateralAssetsIn, address receiver)
        external
        override
        nonReentrant
        returns (uint256 cptAndCstSharesOut)
    {
        _onlyInitialized(poolId);
        _corkPoolDepositAndMintNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        require(collateralAssetsIn != 0, ZeroDeposit());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        // We convert it to 18 fixed decimals, since that's what the Swap Token uses.
        cptAndCstSharesOut = TransferHelper.tokenNativeDecimalsToFixed(collateralAssetsIn, state.collateralDecimals);

        state.pool.balances.collateralAsset.locked += collateralAssetsIn;

        IERC20(state.info.collateralAsset).safeTransferFrom(_msgSender(), address(this), collateralAssetsIn);

        IPoolShare(state.shares.principal).mint(receiver, cptAndCstSharesOut);
        IPoolShare(state.shares.swap).mint(receiver, cptAndCstSharesOut);

        emit PoolModifyLiquidity(poolId, _msgSender(), receiver, collateralAssetsIn, 0, false);
        // ERC4626-compatible event emitted by principal token.
        _emitDeposit(state.shares.principal, _msgSender(), receiver, collateralAssetsIn, cptAndCstSharesOut);
    }

    /// @inheritdoc IPoolManager
    function previewDeposit(MarketId poolId, uint256 collateralAssetsIn)
        external
        view
        returns (uint256 cptAndCstSharesOut)
    {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        if (state._isDepositPaused()) return (0);
        if (state._isExpired()) return (0);

        // 1:1 rate
        cptAndCstSharesOut = TransferHelper.tokenNativeDecimalsToFixed(collateralAssetsIn, state.collateralDecimals);
    }

    /// @inheritdoc IPoolManager
    function maxDeposit(MarketId poolId, address) external view returns (uint256 maxCollateralAssetsIn) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];
        // If Deposit is paused or the market is expired, return 0.
        if (state._isDepositPaused() || state._isExpired()) return 0;

        maxCollateralAssetsIn = type(uint256).max;
    }

    ///======================================================///
    ///================== MINT FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function mint(MarketId poolId, uint256 cptAndCstSharesOut, address receiver)
        external
        nonReentrant
        returns (uint256 collateralAssetsIn)
    {
        _onlyInitialized(poolId);
        _corkPoolDepositAndMintNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        // Since the cPT and cST are 18 decimals, that means the out amount is also 18 decimals.
        collateralAssetsIn =
            TransferHelper.fixedToTokenNativeDecimalsWithCeilDiv(cptAndCstSharesOut, state.collateralDecimals);

        require(collateralAssetsIn != 0, InsufficientAmount());

        state.pool.balances.collateralAsset.locked += collateralAssetsIn;

        IERC20(state.info.collateralAsset).safeTransferFrom(_msgSender(), address(this), collateralAssetsIn);

        IPoolShare(state.shares.principal).mint(receiver, cptAndCstSharesOut);
        IPoolShare(state.shares.swap).mint(receiver, cptAndCstSharesOut);

        emit PoolModifyLiquidity(poolId, _msgSender(), receiver, collateralAssetsIn, 0, false);

        // ERC4626-compatible event emitted by principal token.
        _emitDeposit(state.shares.principal, _msgSender(), receiver, collateralAssetsIn, cptAndCstSharesOut);
    }

    /// @inheritdoc IPoolManager
    function previewMint(MarketId poolId, uint256 cptAndCstSharesOut)
        external
        view
        returns (uint256 collateralAssetsIn)
    {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        if (state._isDepositPaused()) return (0);
        if (state._isExpired()) return (0);

        collateralAssetsIn = TransferHelper.fixedToTokenNativeDecimalsWithCeilDiv(
            cptAndCstSharesOut, data().states[poolId].collateralDecimals
        );
    }

    /// @inheritdoc IPoolManager
    function maxMint(MarketId poolId, address) external view returns (uint256 maxCptAndCstSharesOut) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Minting is paused or the market is expired, return 0
        if (state._isDepositPaused() || state._isExpired()) return 0;

        maxCptAndCstSharesOut = type(uint256).max;
    }

    ///======================================================///
    ///================ UNWIND DEPOSIT FUNCTIONS ============///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function unwindDeposit(MarketId poolId, uint256 collateralAssetsOut, address owner, address receiver)
        external
        nonReentrant
        returns (uint256 cptAndCstSharesIn)
    {
        _onlyInitialized(poolId);
        _corkPoolUnwindDepositAndMintNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];

        cptAndCstSharesIn = TransferHelper.tokenNativeDecimalsToFixed(collateralAssetsOut, state.collateralDecimals);

        require(cptAndCstSharesIn != 0, InvalidAmount());

        state._safeBeforeExpired();

        // Calculate the minimum shares required to get at least 1 unit of collateral asset.
        uint256 minimumShares = _calculateMinimumShares(state.collateralDecimals);

        // Ensure the input amount is at least the minimum required.
        if (cptAndCstSharesIn < minimumShares) revert InsufficientSharesAmount(minimumShares, cptAndCstSharesIn);

        IPoolShare(state.shares.principal).burnFrom(_msgSender(), owner, cptAndCstSharesIn);
        IPoolShare(state.shares.swap).burnFrom(_msgSender(), owner, cptAndCstSharesIn);

        _transferTo(state, receiver, collateralAssetsOut);

        // Emit both events as required by the spec - both cPT and cST are burned equally.
        emit PoolModifyLiquidity(poolId, _msgSender(), owner, collateralAssetsOut, 0, true);
        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(state.shares.principal, _msgSender(), receiver, owner, collateralAssetsOut, cptAndCstSharesIn);
    }

    /// @inheritdoc IPoolManager
    function previewUnwindDeposit(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptAndCstSharesIn)
    {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        if (state._isUnwindDepositPaused()) return (0);
        if (state._isExpired()) return (0);

        // 1:1 rate
        cptAndCstSharesIn = TransferHelper.tokenNativeDecimalsToFixed(collateralAssetsOut, state.collateralDecimals);

        // Calculate the minimum shares required to get at least 1 unit of collateral asset.
        uint256 minimumShares = _calculateMinimumShares(state.collateralDecimals);

        // Ensure the input amount is at least the minimum required.
        if (cptAndCstSharesIn < minimumShares && cptAndCstSharesIn > 0) return 0;
    }

    /// @inheritdoc IPoolManager
    function maxUnwindDeposit(MarketId poolId, address owner) external view returns (uint256 maxCollateralAssetsOut) {
        _onlyInitialized(poolId);
        State storage state = data().states[poolId];

        // If Unwind Deposit is paused or the market is expired, return 0.
        if (state._isUnwindDepositPaused() || state._isExpired()) return 0;

        uint256 ownerSwapTokenBalance = IERC20(state.shares.swap).balanceOf(owner);
        uint256 ownerPrincipalTokenBalance = IERC20(state.shares.principal).balanceOf(owner);

        // Since you need an equal amount of swap token and principal token to unwind, we use whichever is smallest.
        maxCollateralAssetsOut =
            ownerSwapTokenBalance < ownerPrincipalTokenBalance ? ownerSwapTokenBalance : ownerPrincipalTokenBalance;

        // We normalize the decimal to the collateral asset decimal since both the swap and principal token operate with 18 decimals.
        maxCollateralAssetsOut =
            TransferHelper.fixedToTokenNativeDecimals(maxCollateralAssetsOut, state.collateralDecimals);
    }

    ///======================================================///
    ///================ UNWIND MINT FUNCTIONS ===============///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function unwindMint(MarketId poolId, uint256 cptAndCstSharesIn, address owner, address receiver)
        external
        override
        nonReentrant
        returns (uint256 collateralAssetsOut)
    {
        _onlyInitialized(poolId);
        _corkPoolUnwindDepositAndMintNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        require(cptAndCstSharesIn != 0, InvalidAmount());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        // Calculate the minimum shares required to get at least 1 unit of collateral asset.
        uint256 minimumShares = _calculateMinimumShares(state.collateralDecimals);

        // Ensure the input amount is at least the minimum required.
        if (cptAndCstSharesIn < minimumShares) revert InsufficientSharesAmount(minimumShares, cptAndCstSharesIn);
        // Make sure there's no extra shares passed after decimals.
        // We don't use the extra shares(if any) so user shares won't be burned without getting anything back.
        cptAndCstSharesIn = cptAndCstSharesIn - (cptAndCstSharesIn % minimumShares);

        collateralAssetsOut = TransferHelper.fixedToTokenNativeDecimals(cptAndCstSharesIn, state.collateralDecimals);

        IPoolShare(state.shares.principal).burnFrom(_msgSender(), owner, cptAndCstSharesIn);
        IPoolShare(state.shares.swap).burnFrom(_msgSender(), owner, cptAndCstSharesIn);

        _transferTo(state, receiver, collateralAssetsOut);

        // Emit both events as required by the spec - both cPT and cST are burned equally.
        emit PoolModifyLiquidity(poolId, _msgSender(), owner, collateralAssetsOut, 0, true);
        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(state.shares.principal, _msgSender(), receiver, owner, collateralAssetsOut, cptAndCstSharesIn);
    }

    /// @inheritdoc IPoolManager
    function previewUnwindMint(MarketId poolId, uint256 cptAndCstSharesIn)
        external
        view
        returns (uint256 collateralAssetsOut)
    {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        if (state._isUnwindDepositPaused()) return (0);
        if (state._isExpired()) return (0);

        // Calculate minimum shares to avoid rounding issues.
        uint256 minimumShares = _calculateMinimumShares(state.collateralDecimals);

        // Check if amount is less than minimum shares.
        if (cptAndCstSharesIn < minimumShares && cptAndCstSharesIn > 0) return 0; // Return 0 for preview to indicate it's below minimum

        // 1:1 rate
        collateralAssetsOut = TransferHelper.fixedToTokenNativeDecimals(cptAndCstSharesIn, state.collateralDecimals);
    }

    /// @inheritdoc IPoolManager
    function maxUnwindMint(MarketId poolId, address owner) external view returns (uint256 maxCptAndCstSharesIn) {
        _onlyInitialized(poolId);
        State storage state = data().states[poolId];

        // If Unwind Mint is paused or the market is expired, return 0.
        if (state._isUnwindDepositPaused() || state._isExpired()) return 0;

        uint256 ownerSwapTokenBalance = IERC20(state.shares.swap).balanceOf(owner);
        uint256 ownerPrincipalTokenBalance = IERC20(state.shares.principal).balanceOf(owner);

        // Since you need an equal amount of  swap token and principal token to unwind, we use whichever is smallest.
        maxCptAndCstSharesIn =
            ownerSwapTokenBalance < ownerPrincipalTokenBalance ? ownerSwapTokenBalance : ownerPrincipalTokenBalance;
    }

    ///======================================================///
    ///================ REDEEM FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function redeem(MarketId poolId, uint256 cptSharesIn, address owner, address receiver)
        external
        override
        nonReentrant
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut)
    {
        _onlyInitialized(poolId);
        _corkPoolWithdrawalNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];

        require(cptSharesIn != 0, InvalidAmount());
        state._safeAfterExpired();

        // Calculate minimum shares to avoid rounding issues for low decimal tokens.
        uint256 minimumShares = _calculateMinimumSharesForAssets(state.collateralDecimals, state.referenceDecimals);

        // Ensure the input cptSharesIn is at least the minimum required.
        if (cptSharesIn < minimumShares) revert InsufficientSharesAmount(minimumShares, cptSharesIn);

        if (!state.pool.liquiditySeparated) {
            state.pool.liquiditySeparated = true;

            state.pool.poolArchive.collateralAssetAccrued = state.pool.balances.collateralAsset.locked;
            state.pool.poolArchive.referenceAssetAccrued = state.pool.balances.referenceAssetBalance;

            // Reset current balances.
            state.pool.balances.collateralAsset.locked = 0;
            state.pool.balances.referenceAssetBalance = 0;
        }

        CorkPoolPoolArchive storage archive = state.pool.poolArchive;

        (referenceAssetsOut, collateralAssetsOut) = PoolLibrary._calcSwapAmount(
            cptSharesIn,
            IERC20(state.shares.principal).totalSupply(),
            archive.collateralAssetAccrued,
            archive.referenceAssetAccrued
        );

        state.shares.withdrawn += cptSharesIn;
        state.pool.poolArchive.referenceAssetAccrued -= referenceAssetsOut;
        state.pool.poolArchive.collateralAssetAccrued -= collateralAssetsOut;

        IPoolShare(state.shares.principal).burnFrom(_msgSender(), owner, cptSharesIn);
        IERC20(state.info.referenceAsset).safeTransfer(receiver, referenceAssetsOut);
        IERC20(state.info.collateralAsset).safeTransfer(receiver, collateralAssetsOut);

        emit PoolModifyLiquidity(poolId, _msgSender(), owner, collateralAssetsOut, referenceAssetsOut, true);
        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(state.shares.principal, _msgSender(), receiver, owner, collateralAssetsOut, cptSharesIn);
        _emitWithdrawOther(
            state.shares.principal,
            _msgSender(),
            receiver,
            owner,
            address(state.info.referenceAsset),
            referenceAssetsOut,
            cptSharesIn
        );
    }

    /// @inheritdoc IPoolManager
    function previewRedeem(MarketId poolId, uint256 cptSharesIn)
        external
        view
        override
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut)
    {
        _onlyInitialized(poolId);
        (referenceAssetsOut, collateralAssetsOut) = data().states[poolId].previewRedeem(cptSharesIn);
    }

    /// @inheritdoc IPoolManager
    function maxRedeem(MarketId poolId, address owner) external view override returns (uint256 maxCptSharesIn) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Redeem is paused, or the market is not expired yet, return 0.
        if (state._isWithdrawalPaused() || !state._isExpired()) return 0;
        maxCptSharesIn = IERC20(state.shares.principal).balanceOf(owner);
    }

    ///======================================================///
    ///================ WITHDRAW FUNCTIONS ==================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function withdraw(MarketId poolId, uint256 collateralAssetsOut, address owner, address receiver)
        external
        override
        nonReentrant
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        // CollateralAssetsOut must be non-zero
        require(collateralAssetsOut != 0, InvalidParams());
        _onlyWhitelisted(poolId, _msgSender());

        return _withdraw(
            IPoolManager.WithdrawParams({
                poolId: poolId,
                collateralAssetsOut: collateralAssetsOut,
                referenceAssetsOut: 0,
                owner: owner,
                receiver: receiver
            })
        );
    }

    /// @inheritdoc IPoolManager
    function withdrawOther(MarketId poolId, uint256 referenceAssetsOut, address owner, address receiver)
        external
        override
        nonReentrant
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        // ReferenceAssetsOut must be non-zero.
        require(referenceAssetsOut != 0, InvalidParams());
        _onlyWhitelisted(poolId, _msgSender());

        return _withdraw(
            IPoolManager.WithdrawParams({
                poolId: poolId,
                collateralAssetsOut: 0,
                referenceAssetsOut: referenceAssetsOut,
                owner: owner,
                receiver: receiver
            })
        );
    }

    /// @inheritdoc IPoolManager
    function previewWithdraw(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        override
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        _onlyInitialized(poolId);
        (cptSharesIn, actualCollateralAssetsOut, actualReferenceAssetsOut) =
            data().states[poolId].previewWithdraw(collateralAssetsOut);
    }

    /// @inheritdoc IPoolManager
    function previewWithdrawOther(MarketId poolId, uint256 referenceAssetsOut)
        external
        view
        override
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        _onlyInitialized(poolId);
        (cptSharesIn, actualCollateralAssetsOut, actualReferenceAssetsOut) =
            data().states[poolId].previewWithdrawOther(referenceAssetsOut);
    }

    /// @inheritdoc IPoolManager
    function maxWithdraw(MarketId poolId, address owner)
        external
        view
        override
        returns (uint256 maxCollateralAssetsOut)
    {
        _onlyInitialized(poolId);
        (, maxCollateralAssetsOut) = _calculateMaxWithdraw(poolId, owner);
    }

    /// @inheritdoc IPoolManager
    function maxWithdrawOther(MarketId poolId, address owner)
        external
        view
        override
        returns (uint256 maxReferenceAssetsOut)
    {
        _onlyInitialized(poolId);
        (maxReferenceAssetsOut,) = _calculateMaxWithdraw(poolId, owner);
    }

    ///======================================================///
    ///================ SWAP FUNCTIONS ======================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function swap(MarketId poolId, uint256 collateralAssetsOut, address receiver)
        external
        override
        nonReentrant
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee)
    {
        _onlyInitialized(poolId);
        _corkPoolSwapNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        require(collateralAssetsOut != 0, InvalidAmount());

        State storage state = data().states[poolId];

        state._safeBeforeExpired();

        (cstSharesIn, referenceAssetsIn, fee) =
            state.previewSwap(poolId, collateralAssetsOut, _getConstraintRateAdapter());

        require(
            collateralAssetsOut + fee <= state.pool.balances.collateralAsset.locked,
            InsufficientLiquidity(state.pool.balances.collateralAsset.locked, collateralAssetsOut + fee)
        );

        // Update exchange rate because preview doesn't actually update the rate.
        // slither-disable-next-line reentrancy-no-eth,unused-return
        PoolLibrary._getLatestApplicableRateAndUpdate(poolId, _getConstraintRateAdapter());

        state.pool.balances.swapTokenBalance += cstSharesIn;
        state.pool.balances.referenceAssetBalance += referenceAssetsIn;

        IPoolShare(state.shares.swap).transferFrom(_msgSender(), _msgSender(), address(this), cstSharesIn);
        IERC20(state.info.referenceAsset).safeTransferFrom(_msgSender(), address(this), referenceAssetsIn);

        _transferTo(state, receiver, collateralAssetsOut);
        if (fee != 0) _unlockTo(state, _getTreasuryAddress(), fee);

        emit PoolSwap(poolId, _msgSender(), _msgSender(), collateralAssetsOut, referenceAssetsIn, 0, 0, false);
        emit PoolFee(poolId, _msgSender(), fee, 0, false);

        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(state.shares.principal, _msgSender(), receiver, _msgSender(), collateralAssetsOut + fee, 0);
        _emitDepositOther(
            state.shares.principal, _msgSender(), receiver, address(state.info.referenceAsset), referenceAssetsIn, 0
        );
    }

    /// @inheritdoc IPoolManager
    function previewSwap(MarketId poolId, uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee)
    {
        _onlyInitialized(poolId);

        // slither-disable-next-line unused-return
        (cstSharesIn, referenceAssetsIn, fee) =
            data().states[poolId].previewSwap(poolId, collateralAssetsOut, data().CONSTRAINT_ADAPTER);
    }

    /// @inheritdoc IPoolManager
    function maxSwap(MarketId poolId, address owner) external view override returns (uint256 maxCollateralAssetsOut) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Swap is paused or the market is expired, return 0.
        if (state._isSwapPaused() || state._isExpired()) return 0;

        maxCollateralAssetsOut = state.maxSwap(poolId, owner, _getConstraintRateAdapter());
    }

    ///======================================================///
    ///================ EXERCISE FUNCTIONS ==================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function exercise(MarketId poolId, uint256 cstSharesIn, address receiver)
        external
        override
        nonReentrant
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee)
    {
        // Ensure cstSharesIn is non-zero.
        require(cstSharesIn != 0, InvalidParams());

        _onlyInitialized(poolId);
        _corkPoolSwapNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];

        state._safeBeforeExpired();

        (collateralAssetsOut, referenceAssetsIn, fee) =
            state.previewExercise(poolId, cstSharesIn, _getConstraintRateAdapter());

        _exercise(
            state,
            ExerciseParams({
                poolId: poolId,
                receiver: receiver,
                collateralAssetsOut: collateralAssetsOut,
                cstSharesIn: cstSharesIn,
                referenceAssetsIn: referenceAssetsIn,
                fee: fee
            })
        );
    }

    /// @inheritdoc IPoolManager
    function exerciseOther(MarketId poolId, uint256 referenceAssetsIn, address receiver)
        external
        override
        nonReentrant
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee)
    {
        // Ensure referenceAssetsIn is non-zero.
        require(referenceAssetsIn != 0, InvalidParams());

        _onlyInitialized(poolId);
        _corkPoolSwapNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];

        state._safeBeforeExpired();

        (collateralAssetsOut, cstSharesIn, fee) =
            state.previewExerciseOther(poolId, referenceAssetsIn, _getConstraintRateAdapter());

        _exercise(
            state,
            ExerciseParams({
                poolId: poolId,
                receiver: receiver,
                collateralAssetsOut: collateralAssetsOut,
                cstSharesIn: cstSharesIn,
                referenceAssetsIn: referenceAssetsIn,
                fee: fee
            })
        );
    }

    /// @inheritdoc IPoolManager
    function previewExercise(MarketId poolId, uint256 cstSharesIn)
        external
        view
        override
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee)
    {
        _onlyInitialized(poolId);
        // slither-disable-next-line unused-return
        (collateralAssetsOut, referenceAssetsIn, fee) =
            data().states[poolId].previewExercise(poolId, cstSharesIn, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function previewExerciseOther(MarketId poolId, uint256 referenceAssetsIn)
        external
        view
        override
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee)
    {
        _onlyInitialized(poolId);

        // slither-disable-next-line unused-return
        (collateralAssetsOut, cstSharesIn, fee) =
            data().states[poolId].previewExerciseOther(poolId, referenceAssetsIn, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function maxExercise(MarketId poolId, address owner) external view override returns (uint256 maxCstSharesIn) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Exercise is paused or the market is expired, return 0.
        if (state._isSwapPaused() || state._isExpired()) return 0;

        return state.maxExercise(poolId, owner, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function maxExerciseOther(MarketId poolId, address owner)
        external
        view
        override
        returns (uint256 maxReferenceAssetsIn)
    {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Exercise is paused or the market is expired, return 0.
        if (state._isSwapPaused() || state._isExpired()) return 0;

        return state.maxExerciseOther(poolId, owner, _getConstraintRateAdapter());
    }

    ///======================================================///
    ///================ UNWIND SWAP FUNCTIONS ===============///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function unwindSwap(MarketId poolId, uint256 collateralAssetsIn, address receiver)
        external
        override
        nonReentrant
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee)
    {
        _onlyInitialized(poolId);
        _corkPoolUnwindSwapAndExerciseNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        require(collateralAssetsIn != 0, InvalidAmount());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        (cstSharesOut, referenceAssetsOut, fee) =
            state.previewUnwindSwap(poolId, collateralAssetsIn, _getConstraintRateAdapter());

        // Check sufficient liquidity.
        require(
            referenceAssetsOut <= state.pool.balances.referenceAssetBalance,
            InsufficientLiquidity(state.pool.balances.referenceAssetBalance, referenceAssetsOut)
        );
        require(
            cstSharesOut <= state.pool.balances.swapTokenBalance,
            InsufficientLiquidity(state.pool.balances.swapTokenBalance, cstSharesOut)
        );

        // Actually update the rate, since preview only get the latest rate without updating.
        // The adjusted rate should be idempotent and is fine to call many times.
        // slither-disable-next-line reentrancy-no-eth,unused-return
        PoolLibrary._getLatestApplicableRateAndUpdate(poolId, _getConstraintRateAdapter());

        // Decrease Cork Pool balance.
        // We also include the fee here to separate the accumulated fee from the unwindSwap.
        state.pool.balances.referenceAssetBalance -= (referenceAssetsOut);
        state.pool.balances.swapTokenBalance -= (cstSharesOut);
        state.pool.balances.collateralAsset.locked += collateralAssetsIn;

        // Transfer the fee(if any) to treasury, since the fee is used to provide liquidity.
        IERC20(state.info.collateralAsset).safeTransferFrom(_msgSender(), address(this), collateralAssetsIn);

        // slither-disable-next-line reentrancy-no-eth
        if (fee != 0) _unlockTo(state, _getTreasuryAddress(), fee);

        // Transfer user attributed Swap Token + Reference Asset.
        IERC20(state.info.referenceAsset).safeTransfer(receiver, referenceAssetsOut);
        IERC20(state.shares.swap).safeTransfer(receiver, cstSharesOut);

        emit PoolSwap(poolId, _msgSender(), receiver, collateralAssetsIn, referenceAssetsOut, 0, 0, true);
        emit PoolFee(poolId, _msgSender(), fee, 0, true);

        // ERC4626-compatible event emitted by principal token.
        _emitDeposit(state.shares.principal, _msgSender(), receiver, collateralAssetsIn - fee, 0);
        _emitWithdrawOther(
            state.shares.principal,
            _msgSender(),
            receiver,
            _msgSender(),
            address(state.info.referenceAsset),
            referenceAssetsOut,
            0
        );
    }

    /// @inheritdoc IPoolManager
    function previewUnwindSwap(MarketId poolId, uint256 collateralAssetsIn)
        external
        view
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee)
    {
        _onlyInitialized(poolId);
        (cstSharesOut, referenceAssetsOut, fee) =
            data().states[poolId].previewUnwindSwap(poolId, collateralAssetsIn, data().CONSTRAINT_ADAPTER);
    }

    /// @inheritdoc IPoolManager
    function maxUnwindSwap(MarketId poolId, address) external view returns (uint256 maxCollateralAssetsIn) {
        _onlyInitialized(poolId);

        State storage state = data().states[poolId];

        // If Unwind Swap is paused or the market is expired, return 0.
        if (state._isUnwindSwapPaused() || state._isExpired()) return 0;

        maxCollateralAssetsIn = state.maxUnwindSwap(poolId, _getConstraintRateAdapter());
    }

    ///======================================================///
    ///================ UNWIND EXERCISE FUNCTIONS ===========///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function unwindExercise(MarketId poolId, uint256 cstSharesOut, address receiver)
        external
        override
        nonReentrant
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee)
    {
        // Ensure cstSharesOut is non-zero.
        require(cstSharesOut != 0, InvalidAmount());

        _onlyInitialized(poolId);
        _corkPoolUnwindSwapAndExerciseNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        (collateralAssetsIn, fee, referenceAssetsOut) =
            state.previewUnwindExercise(poolId, cstSharesOut, _getConstraintRateAdapter());

        _unwindExercise(
            state,
            UnwindExerciseParams({
                poolId: poolId,
                receiver: receiver,
                cstSharesOut: cstSharesOut,
                referenceAssetsOut: referenceAssetsOut,
                collateralAssetsIn: collateralAssetsIn,
                fee: fee
            })
        );
    }

    /// @inheritdoc IPoolManager
    function unwindExerciseOther(MarketId poolId, uint256 referenceAssetsOut, address receiver)
        external
        override
        nonReentrant
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee)
    {
        // Ensure referenceAssetsOut is non-zero.
        require(referenceAssetsOut != 0, InvalidAmount());

        _onlyInitialized(poolId);
        _corkPoolUnwindSwapAndExerciseNotPaused(poolId);
        _onlyWhitelisted(poolId, _msgSender());

        State storage state = data().states[poolId];
        state._safeBeforeExpired();

        (collateralAssetsIn, fee, cstSharesOut) =
            state.previewUnwindExerciseOther(poolId, referenceAssetsOut, _getConstraintRateAdapter());

        _unwindExercise(
            state,
            UnwindExerciseParams({
                poolId: poolId,
                receiver: receiver,
                cstSharesOut: cstSharesOut,
                referenceAssetsOut: referenceAssetsOut,
                collateralAssetsIn: collateralAssetsIn,
                fee: fee
            })
        );
    }

    /// @inheritdoc IPoolManager
    function previewUnwindExercise(MarketId poolId, uint256 cstSharesOut)
        external
        view
        override
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee)
    {
        _onlyInitialized(poolId);
        // slither-disable-next-line unused-return
        (collateralAssetsIn, fee, referenceAssetsOut) =
            data().states[poolId].previewUnwindExercise(poolId, cstSharesOut, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function previewUnwindExerciseOther(MarketId poolId, uint256 referenceAssetsOut)
        external
        view
        override
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee)
    {
        _onlyInitialized(poolId);
        // slither-disable-next-line unused-return
        (collateralAssetsIn, fee, cstSharesOut) =
            data().states[poolId].previewUnwindExerciseOther(poolId, referenceAssetsOut, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function maxUnwindExercise(MarketId poolId, address) external view override returns (uint256 maxCstSharesOut) {
        _onlyInitialized(poolId);
        State storage state = data().states[poolId];

        // If Unwind Exercise is paused or the market is expired, return 0.
        if (state._isUnwindSwapPaused() || state._isExpired()) return 0;

        maxCstSharesOut = state.maxUnwindExercise(poolId, _getConstraintRateAdapter());
    }

    /// @inheritdoc IPoolManager
    function maxUnwindExerciseOther(MarketId poolId, address)
        external
        view
        override
        returns (uint256 maxReferenceAssetsOut)
    {
        _onlyInitialized(poolId);
        State storage state = data().states[poolId];

        // If Unwind Exercise is paused or the market is expired, return 0.
        if (state._isUnwindSwapPaused() || state._isExpired()) return 0;

        maxReferenceAssetsOut = state.maxUnwindExerciseOther(poolId, _getConstraintRateAdapter());
    }

    ///======================================================///
    ///============= RATE & FEE RELATED FUNCTIONS ===========///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function swapRate(MarketId poolId) external view override returns (uint256 rate) {
        rate = PoolLibrary.swapRate(poolId, data().CONSTRAINT_ADAPTER);
    }

    /// @inheritdoc IPoolManager
    function swapFee(MarketId poolId) external view override returns (uint256 fees) {
        fees = data().states[poolId].pool.swapFeePercentage;
    }

    /// @inheritdoc IPoolManager
    function unwindSwapFee(MarketId poolId) external view override returns (uint256 fees) {
        fees = data().states[poolId].unwindSwapFeePercentage();
    }

    /// @inheritdoc IPoolManager
    function updateSwapFeePercentage(MarketId poolId, uint256 newSwapFeePercentage) external {
        _onlyInitialized(poolId);
        _onlyCorkController();

        PoolLibrary.updateSwapFeePercentage(data().states[poolId], newSwapFeePercentage);
        emit SwapFeePercentageUpdated(poolId, newSwapFeePercentage);
    }

    /// @inheritdoc IPoolManager
    function updateUnwindSwapFeePercentage(MarketId poolId, uint256 newUnwindSwapFeePercentage) external {
        _onlyInitialized(poolId);
        _onlyCorkController();
        PoolLibrary.updateUnwindSwapFeePercentage(data().states[poolId], newUnwindSwapFeePercentage);

        emit UnwindSwapFeePercentageUpdated(poolId, newUnwindSwapFeePercentage);
    }

    ///======================================================///
    ///================ ADMINISTRATIVE FUNCTIONS ============///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function setPausedBitMap(MarketId poolId, uint16 newPauseBitMap) external {
        _onlyInitialized(poolId);
        _onlyCorkController();

        require(newPauseBitMap >> 5 == 0, InvalidParams()); // Bitmap flag is outside the current range [0,4]

        State storage state = data().states[poolId];

        require(state.pool.pauseBitMap != newPauseBitMap, SameStatus());

        state.pool.pauseBitMap = newPauseBitMap;
        emit MarketActionPausedUpdate(poolId, newPauseBitMap);
    }

    /// @inheritdoc IPoolManager
    function setAllPaused(bool isAllPaused) external {
        _onlyCorkController();
        if (isAllPaused) _pause();
        else _unpause();
    }

    /// @inheritdoc IPoolManager
    function setTreasuryAddress(address newTreasury) external {
        _onlyCorkController();

        data().TREASURY = newTreasury;

        emit TreasurySet(newTreasury);
    }

    /// @inheritdoc IPoolManager
    function setSharesFactory(address newSharesFactory) external {
        _onlyCorkController();

        data().SHARES_FACTORY = newSharesFactory;

        emit SharesFactorySet(newSharesFactory);
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IPoolManager
    function getPausedBitMap(MarketId poolId) external view returns (uint16 pauseBitMap) {
        pauseBitMap = data().states[poolId].pool.pauseBitMap;
    }

    /// @inheritdoc IPoolManager
    function shares(MarketId poolId) external view override returns (address principalToken, address swapToken) {
        State memory state = data().states[poolId];
        principalToken = state.shares.principal;
        swapToken = state.shares.swap;
    }

    /// @inheritdoc IPoolManager
    function assets(MarketId poolId)
        external
        view
        override
        returns (uint256 collateralAssets, uint256 referenceAssets)
    {
        State storage state = data().states[poolId];

        if (state.pool.liquiditySeparated) {
            collateralAssets = state.pool.poolArchive.collateralAssetAccrued;
            referenceAssets = state.pool.poolArchive.referenceAssetAccrued;
        } else {
            collateralAssets = state.pool.balances.collateralAsset.locked;
            referenceAssets = state.pool.balances.referenceAssetBalance;
        }
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    /// @notice Authorization function for UUPS proxy upgrades.
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @dev checks if caller address is having CORK_CONTROLLER_ROLE or not
    function _onlyCorkController() internal view {
        require(hasRole(CORK_CONTROLLER_ROLE, _msgSender()), OnlyCorkControllerAllowed());
    }

    /// @dev checks if caller is whitelisted for the specific market
    function _onlyWhitelisted(MarketId poolId, address account) internal view {
        if (!IWhitelistManager(_getWhitelistManager()).isWhitelisted(poolId, account)) {
            revert NotWhitelisted(account, MarketId.unwrap(poolId));
        }
    }

    /// @dev Either cstSharesIn or referenceAssetsIn MUST be 0.
    function _exercise(State storage state, ExerciseParams memory params) internal {
        // Update swap rate since preview doesn't update the rate.
        // slither-disable-next-line reentrancy-no-eth,unused-return
        PoolLibrary._getLatestApplicableRateAndUpdate(params.poolId, _getConstraintRateAdapter());

        // Check sufficient liquidity.
        require(
            params.collateralAssetsOut + params.fee <= state.pool.balances.collateralAsset.locked,
            InsufficientLiquidity(state.pool.balances.collateralAsset.locked, params.collateralAssetsOut + params.fee)
        );

        state.pool.balances.swapTokenBalance += params.cstSharesIn;
        state.pool.balances.referenceAssetBalance += params.referenceAssetsIn;

        IPoolShare(state.shares.swap).transferFrom(_msgSender(), _msgSender(), address(this), params.cstSharesIn);
        IERC20(state.info.referenceAsset).safeTransferFrom(_msgSender(), address(this), params.referenceAssetsIn);

        _transferTo(state, params.receiver, params.collateralAssetsOut);
        if (params.fee != 0) _unlockTo(state, _getTreasuryAddress(), params.fee);

        emit PoolSwap(
            params.poolId, _msgSender(), _msgSender(), params.collateralAssetsOut, params.referenceAssetsIn, 0, 0, false
        );
        emit PoolFee(params.poolId, _msgSender(), params.fee, 0, false);

        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(
            state.shares.principal,
            _msgSender(),
            params.receiver,
            _msgSender(),
            params.collateralAssetsOut + params.fee,
            0
        );
        _emitDepositOther(
            state.shares.principal,
            _msgSender(),
            params.receiver,
            address(state.info.referenceAsset),
            params.referenceAssetsIn,
            0
        );
    }

    /// @dev Either collateralAssetsOut or referenceAssetsOut MUST be 0.
    function _withdraw(WithdrawParams memory params)
        internal
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        _onlyInitialized(params.poolId);
        _corkPoolWithdrawalNotPaused(params.poolId);

        State storage state = data().states[params.poolId];

        state._safeAfterExpired();

        if (!state.pool.liquiditySeparated) {
            state.pool.liquiditySeparated = true;

            state.pool.poolArchive.collateralAssetAccrued = state.pool.balances.collateralAsset.locked;
            state.pool.poolArchive.referenceAssetAccrued = state.pool.balances.referenceAssetBalance;

            // Reset current balances.
            state.pool.balances.collateralAsset.locked = 0;
            state.pool.balances.referenceAssetBalance = 0;
        }

        // Calculate required shares.
        CorkPoolPoolArchive storage archive = state.pool.poolArchive;

        require(
            params.collateralAssetsOut <= archive.collateralAssetAccrued,
            InsufficientLiquidity(archive.collateralAssetAccrued, params.collateralAssetsOut)
        );
        require(
            params.referenceAssetsOut <= archive.referenceAssetAccrued,
            InsufficientLiquidity(archive.referenceAssetAccrued, params.referenceAssetsOut)
        );

        cptSharesIn = PoolLibrary._calcWithdrawAmount(
            params.collateralAssetsOut,
            params.referenceAssetsOut,
            IERC20(state.shares.principal).totalSupply(),
            archive.collateralAssetAccrued,
            archive.referenceAssetAccrued
        );

        // Calculate minimum shares to avoid rounding issues for low decimal tokens.
        uint256 minimumShares = _calculateMinimumSharesForAssets(state.collateralDecimals, state.referenceDecimals);

        // Ensure the input amount is at least the minimum required.
        if (cptSharesIn < minimumShares) revert InsufficientSharesAmount(minimumShares, cptSharesIn);

        (actualReferenceAssetsOut, actualCollateralAssetsOut) = PoolLibrary._calcSwapAmount(
            cptSharesIn,
            IERC20(state.shares.principal).totalSupply(),
            archive.collateralAssetAccrued,
            archive.referenceAssetAccrued
        );

        state.shares.withdrawn += cptSharesIn;
        state.pool.poolArchive.referenceAssetAccrued -= actualReferenceAssetsOut;
        state.pool.poolArchive.collateralAssetAccrued -= actualCollateralAssetsOut;

        IPoolShare(state.shares.principal).burnFrom(_msgSender(), params.owner, cptSharesIn);
        IERC20(state.info.referenceAsset).safeTransfer(params.receiver, actualReferenceAssetsOut);
        IERC20(state.info.collateralAsset).safeTransfer(params.receiver, actualCollateralAssetsOut);

        emit PoolModifyLiquidity(
            params.poolId, _msgSender(), params.owner, actualCollateralAssetsOut, actualReferenceAssetsOut, true
        );
        // ERC4626-compatible event emitted by principal token.
        _emitWithdraw(
            state.shares.principal, _msgSender(), params.receiver, params.owner, actualCollateralAssetsOut, cptSharesIn
        );
        _emitWithdrawOther(
            state.shares.principal,
            _msgSender(),
            params.receiver,
            params.owner,
            address(state.info.referenceAsset),
            actualReferenceAssetsOut,
            cptSharesIn
        );
    }

    /// @dev Either shares or referenceAsset MUST be 0.
    function _unwindExercise(State storage state, UnwindExerciseParams memory params) internal {
        // Check sufficient liquidity.
        require(
            params.referenceAssetsOut <= state.pool.balances.referenceAssetBalance,
            InsufficientLiquidity(state.pool.balances.referenceAssetBalance, params.referenceAssetsOut)
        );
        require(
            params.cstSharesOut <= state.pool.balances.swapTokenBalance,
            InsufficientLiquidity(state.pool.balances.swapTokenBalance, params.cstSharesOut)
        );

        // Decrease pool balances (opposite of unwindSwap).
        state.pool.balances.referenceAssetBalance -= params.referenceAssetsOut;
        state.pool.balances.swapTokenBalance -= params.cstSharesOut;
        state.pool.balances.collateralAsset.locked += params.collateralAssetsIn;

        // Atually update the rate, since preview only get the latest rate without updating
        // the adjusted rate should be idempotent and is fine to call many times.
        // slither-disable-next-line reentrancy-no-eth,unused-return
        PoolLibrary._getLatestApplicableRateAndUpdate(params.poolId, _getConstraintRateAdapter());

        IERC20(state.info.collateralAsset).safeTransferFrom(_msgSender(), address(this), params.collateralAssetsIn);

        // Transfer collateral asset fees to treasury.
        if (params.fee != 0) _unlockTo(state, _getTreasuryAddress(), params.fee);

        // Transfer unlocked tokens to receiver.
        IERC20(state.info.referenceAsset).safeTransfer(params.receiver, params.referenceAssetsOut);
        IERC20(state.shares.swap).safeTransfer(params.receiver, params.cstSharesOut);

        emit PoolSwap(
            params.poolId,
            _msgSender(),
            params.receiver,
            params.collateralAssetsIn,
            params.referenceAssetsOut,
            0,
            0,
            true
        );
        emit PoolFee(params.poolId, _msgSender(), params.fee, 0, true);

        // ERC4626-compatible event emitted by principal token
        _emitDeposit(state.shares.principal, _msgSender(), params.receiver, params.collateralAssetsIn - params.fee, 0);
        _emitWithdrawOther(
            state.shares.principal,
            _msgSender(),
            params.receiver,
            _msgSender(),
            address(state.info.referenceAsset),
            params.referenceAssetsOut,
            0
        );
    }

    /// @notice Transfer fees to treasury (used only for fee transfers to treasury).
    /// @dev Current Implementation is a PUSH model that overcharges for fees to avoid rounding issues. We will update it to a PULL model in the future if necessary
    /// @param state The state of the pool.
    /// @param treasury The address to transfer the asset to (treasury address).
    /// @param feeCollateralAssetsOut The amount of collateral assets fees to transfer.
    function _unlockTo(State storage state, address treasury, uint256 feeCollateralAssetsOut) internal {
        _transferTo(state, treasury, feeCollateralAssetsOut);
    }

    /// @notice Transfer assets to receiver (used only for asset transfers to receiver).
    /// @param state The state of the pool.
    /// @param receiver The address to transfer the asset to (receiver address).
    /// @param collateralAssetsOut The amount of collateral assets to transfer.
    function _transferTo(State storage state, address receiver, uint256 collateralAssetsOut) internal {
        // If collateralAssetsOut is greater than locked amount, revert.
        require(collateralAssetsOut <= state.pool.balances.collateralAsset.locked, InvalidAmount());

        // Decrease locked amount.
        state.pool.balances.collateralAsset.locked -= collateralAssetsOut;

        // Transfer asset to receiver.
        IERC20(state.info.collateralAsset).safeTransfer(receiver, collateralAssetsOut);
    }

    function _calculateMaxWithdraw(MarketId poolId, address owner)
        private
        view
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut)
    {
        State storage state = data().states[poolId];

        // If withdrawals are paused or the market is not expired yet, return 0.
        if (state._isWithdrawalPaused() || !state._isExpired()) return (0, 0);

        // Get owner's cPT balance (shares).
        uint256 ownerCptSharesBalance = IERC20(state.shares.principal).balanceOf(owner);

        // prevents unnecessary gas consumption on previewRedeem.
        // slither-disable-next-line incorrect-equality
        if (ownerCptSharesBalance == 0) return (0, 0);

        // Return the minimum of owner's shares and available collateral.
        // This ensures we don't return more than what can actually be withdrawn.
        (referenceAssetsOut, collateralAssetsOut) = state.previewRedeem(ownerCptSharesBalance);
    }

    /// @notice Calculates minimum shares required to avoid rounding to zero.
    /// @dev Returns 10^(18-decimals).
    /// @param decimals The number of decimals for the token.
    /// @return minimumShares The minimum shares required.
    function _calculateMinimumShares(uint8 decimals) internal pure returns (uint256 minimumShares) {
        return 10 ** (18 - decimals);
    }

    /// @notice Calculates minimum shares based on the lowest decimal count between two assets.
    /// @param collateralDecimals Decimals of collateral asset.
    /// @param referenceDecimals Decimals of reference asset.
    /// @return minimumShares Minimum shares required.
    function _calculateMinimumSharesForAssets(uint8 collateralDecimals, uint8 referenceDecimals)
        internal
        pure
        returns (uint256 minimumShares)
    {
        // Use the asset with the lowest decimals to calculate minimum shares.
        uint8 lowestDecimals = collateralDecimals < referenceDecimals ? collateralDecimals : referenceDecimals;
        return _calculateMinimumShares(lowestDecimals);
    }

    function _corkPoolDepositAndMintNotPaused(MarketId id) internal view {
        require(!paused(), EnforcedPause());
        require(!PoolLibrary._isDepositPaused(data().states[id]), EnforcedPause());
    }

    function _corkPoolSwapNotPaused(MarketId id) internal view {
        require(!paused(), EnforcedPause());
        require(!PoolLibrary._isSwapPaused(data().states[id]), EnforcedPause());
    }

    function _corkPoolWithdrawalNotPaused(MarketId id) internal view {
        require(!paused(), EnforcedPause());
        require(!PoolLibrary._isWithdrawalPaused(data().states[id]), EnforcedPause());
    }

    function _corkPoolUnwindDepositAndMintNotPaused(MarketId id) internal view {
        require(!paused(), EnforcedPause());
        require(!PoolLibrary._isUnwindDepositPaused(data().states[id]), EnforcedPause());
    }

    function _corkPoolUnwindSwapAndExerciseNotPaused(MarketId id) internal view {
        require(!paused(), EnforcedPause());
        require(!PoolLibrary._isUnwindSwapPaused(data().states[id]), EnforcedPause());
    }

    function _emitDeposit(
        address sharesAddress,
        address sender,
        address receiver,
        uint256 assetsInWithoutFee,
        uint256 sharesToReceive
    ) internal {
        IPoolShare(sharesAddress).emitDeposit(sender, receiver, assetsInWithoutFee, sharesToReceive);
    }

    function _emitDepositOther(
        address sharesAddress,
        address sender,
        address owner,
        address asset,
        uint256 referenceAssetsInWithoutFee,
        uint256 sharesToReceive
    ) internal {
        IPoolShare(sharesAddress).emitDepositOther(sender, owner, asset, referenceAssetsInWithoutFee, sharesToReceive);
    }

    function _emitWithdraw(
        address sharesAddress,
        address sender,
        address receiver,
        address owner,
        uint256 assetsOut,
        uint256 sharesIn
    ) internal {
        IPoolShare(sharesAddress).emitWithdraw(sender, receiver, owner, assetsOut, sharesIn);
    }

    function _emitWithdrawOther(
        address sharesAddress,
        address sender,
        address receiver,
        address owner,
        address asset,
        uint256 assetsOut,
        uint256 sharesIn
    ) internal {
        IPoolShare(sharesAddress).emitWithdrawOther(sender, receiver, owner, asset, assetsOut, sharesIn);
    }
}
