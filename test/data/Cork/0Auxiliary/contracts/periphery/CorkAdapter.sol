// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ErrorsLib} from "bundler3/libraries/ErrorsLib.sol";
import {ICorkAdapter} from "contracts/interfaces/ICorkAdapter.sol";
import {IPoolManager, Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {IWhitelistManager} from "contracts/interfaces/IWhitelistManager.sol";
import {GeneralAdapter} from "contracts/periphery/GeneralAdapter.sol";

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

/// @title CorkAdapter
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Adapter contract integrating Cork PoolManager with generic actions and Bundler3.
contract CorkAdapter is Ownable, GeneralAdapter, ICorkAdapter {
    /// @notice The address of the core Cork contract.
    // slither-disable-next-line naming-convention
    IPoolManager public CORK;

    /// @notice The address of the whitelist manager contract.
    // slither-disable-next-line naming-convention
    IWhitelistManager public WHITELIST_MANAGER;

    /// @param initialOwner The initial owner
    constructor(address initialOwner) Ownable(initialOwner) GeneralAdapter() {}

    /// @inheritdoc ICorkAdapter
    function initialize(address ensOwner, address bundler3, address cork, address whitelistManager) external onlyOwner {
        // Can't initialize more than once.
        require(address(BUNDLER3) == address(0), InvalidInitialization());

        require(bundler3 != address(0), ErrorsLib.ZeroAddress());
        require(ensOwner != address(0), ErrorsLib.ZeroAddress());
        require(cork != address(0), ErrorsLib.ZeroAddress());
        require(address(whitelistManager) != address(0), ErrorsLib.ZeroAddress());

        BUNDLER3 = bundler3;
        CORK = IPoolManager(cork);
        WHITELIST_MANAGER = IWhitelistManager(whitelistManager);

        // After initialization, owner should only be used for ENS management.
        _transferOwnership(ensOwner);
    }

    ///======================================================///
    ///=================== MODIFIERS ========================///
    ///======================================================///

    modifier onlyWhitelisted(MarketId poolId) {
        require(WHITELIST_MANAGER.isWhitelisted(poolId, initiator()), ErrorsLib.UnauthorizedSender());
        _;
    }

    ///======================================================///
    ///=========== CORK POOL MANAGER FUNCTIONS ==============///
    ///======================================================///

    /// @inheritdoc ICorkAdapter
    function safeMint(SafeMintParams calldata params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.cptAndCstSharesOut != 0, ErrorsLib.ZeroShares());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);

        IERC20 cpt;
        IERC20 cst;
        {
            (address principalToken, address swapToken) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
            cst = IERC20(swapToken);
        }

        // Snapshot collateral balance before operation.
        uint256 collateralBefore = collateralAsset.balanceOf(address(this));
        uint256 cptBefore = cpt.balanceOf(params.receiver);
        uint256 cstBefore = cst.balanceOf(params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        CORK.mint(params.poolId, params.cptAndCstSharesOut, params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), 0);

        // Calculate actual collateral spent and check slippage protection.
        uint256 collateralAfter = collateralAsset.balanceOf(address(this));
        uint256 cptAfter = cpt.balanceOf(params.receiver);
        uint256 cstAfter = cst.balanceOf(params.receiver);

        uint256 actualCollateralIn = collateralBefore - collateralAfter;
        uint256 actualCptOut = cptAfter - cptBefore;
        uint256 actualCstOut = cstAfter - cstBefore;

        require(actualCollateralIn <= params.maxCollateralAssetsIn, ErrorsLib.SlippageExceeded());
        require(actualCptOut >= params.cptAndCstSharesOut, ErrorsLib.SlippageExceeded());
        require(actualCstOut >= params.cptAndCstSharesOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeDeposit(SafeDepositParams calldata params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.collateralAssetsIn != 0, ErrorsLib.ZeroAmount());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);

        IERC20 cpt;
        IERC20 cst;
        {
            (address principalToken, address swapToken) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 collateralBefore = collateralAsset.balanceOf(address(this));
        uint256 cptBefore = cpt.balanceOf(params.receiver);
        uint256 cstBefore = cst.balanceOf(params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        CORK.deposit(params.poolId, params.collateralAssetsIn, params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), 0);

        // Calculate actual changes and check slippage protection.
        uint256 collateralAfter = collateralAsset.balanceOf(address(this));
        uint256 cptAfter = cpt.balanceOf(params.receiver);
        uint256 cstAfter = cst.balanceOf(params.receiver);

        uint256 actualCollateralIn = collateralBefore - collateralAfter;
        uint256 actualCptOut = cptAfter - cptBefore;
        uint256 actualCstOut = cstAfter - cstBefore;

        require(actualCollateralIn <= params.collateralAssetsIn, ErrorsLib.SlippageExceeded());
        require(actualCptOut >= params.minCptAndCstSharesOut, ErrorsLib.SlippageExceeded());
        require(actualCstOut >= params.minCptAndCstSharesOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeUnwindDeposit(SafeUnwindDepositParams calldata params)
        external
        onlyBundler3
        onlyWhitelisted(params.poolId)
    {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.owner == address(this) || params.owner == initiator(), ErrorsLib.UnexpectedOwner());
        require(params.collateralAssetsOut != 0, ErrorsLib.ZeroAmount());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);

        IERC20 cpt;
        IERC20 cst;
        {
            (address principalToken, address swapToken) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 cptBefore = cpt.balanceOf(params.owner);
        uint256 cstBefore = cst.balanceOf(params.owner);
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);

        // slither-disable-next-line unused-return
        CORK.unwindDeposit(params.poolId, params.collateralAssetsOut, params.owner, params.receiver);

        // Calculate actual changes and check slippage protection.
        uint256 cptAfter = cpt.balanceOf(params.owner);
        uint256 cstAfter = cst.balanceOf(params.owner);
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);

        uint256 actualCptIn = cptBefore - cptAfter;
        uint256 actualCstIn = cstBefore - cstAfter;
        uint256 actualCollateralOut = collateralAfter - collateralBefore;

        require(actualCptIn <= params.maxCptAndCstSharesIn, ErrorsLib.SlippageExceeded());
        require(actualCstIn <= params.maxCptAndCstSharesIn, ErrorsLib.SlippageExceeded());
        require(actualCollateralOut >= params.collateralAssetsOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeUnwindMint(SafeUnwindMintParams memory params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.owner == address(this) || params.owner == initiator(), ErrorsLib.UnexpectedOwner());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);

        IERC20 cpt;
        IERC20 cst;
        {
            (address principalToken, address swapToken) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 cptBefore = cpt.balanceOf(params.owner);
        uint256 cstBefore = cst.balanceOf(params.owner);
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);

        if (params.cptAndCstSharesIn == type(uint256).max) {
            // Use the minimum of cPT and cST balances from owner.
            uint256 cptBalance = params.owner == address(this)
                ? cpt.balanceOf(params.owner)
                : cpt.allowance(params.owner, address(this));
            uint256 cstBalance = params.owner == address(this)
                ? cst.balanceOf(params.owner)
                : cst.allowance(params.owner, address(this));
            params.cptAndCstSharesIn = cptBalance < cstBalance ? cptBalance : cstBalance;
        }

        require(params.cptAndCstSharesIn != 0, ErrorsLib.ZeroShares());

        // slither-disable-next-line unused-return
        CORK.unwindMint(params.poolId, params.cptAndCstSharesIn, params.owner, params.receiver);

        // Calculate actual changes and check slippage protection.
        uint256 cptAfter = cpt.balanceOf(params.owner);
        uint256 cstAfter = cst.balanceOf(params.owner);
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);

        uint256 actualCptIn = cptBefore - cptAfter;
        uint256 actualCstIn = cstBefore - cstAfter;
        uint256 actualCollateralOut = collateralAfter - collateralBefore;

        require(actualCptIn <= params.cptAndCstSharesIn, ErrorsLib.SlippageExceeded());
        require(actualCstIn <= params.cptAndCstSharesIn, ErrorsLib.SlippageExceeded());
        require(actualCollateralOut >= params.minCollateralAssetsOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeWithdraw(SafeWithdrawParams calldata params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // Ensure collateralAssets is not 0.
        require(params.collateralAssetsOut != 0, ErrorsLib.ZeroAmount());

        _safeWithdraw(
            SafeWithdrawInternalParams({
                poolId: params.poolId,
                collateralAssetsOut: params.collateralAssetsOut,
                referenceAssetsOut: 0,
                owner: params.owner,
                receiver: params.receiver,
                maxCptSharesIn: params.maxCptSharesIn,
                deadline: params.deadline
            })
        );
    }

    /// @inheritdoc ICorkAdapter
    function safeWithdrawOther(SafeWithdrawOtherParams calldata params)
        external
        onlyBundler3
        onlyWhitelisted(params.poolId)
    {
        // Ensure referenceAssets is not 0.
        require(params.referenceAssetsOut != 0, ErrorsLib.ZeroAmount());

        _safeWithdraw(
            SafeWithdrawInternalParams({
                poolId: params.poolId,
                collateralAssetsOut: 0,
                referenceAssetsOut: params.referenceAssetsOut,
                owner: params.owner,
                receiver: params.receiver,
                maxCptSharesIn: params.maxCptSharesIn,
                deadline: params.deadline
            })
        );
    }

    /// @inheritdoc ICorkAdapter
    function safeRedeem(SafeRedeemParams memory params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.owner == address(this) || params.owner == initiator(), ErrorsLib.UnexpectedOwner());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cpt;
        {
            // slither-disable-next-line unused-return
            (address principalToken,) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
        }

        // Snapshot balances before operation.
        uint256 cptBefore = cpt.balanceOf(params.owner);
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);
        uint256 referenceBefore = referenceAsset.balanceOf(params.receiver);

        if (params.cptSharesIn == type(uint256).max) {
            params.cptSharesIn = params.owner == address(this)
                ? cpt.balanceOf(params.owner)
                : cpt.allowance(params.owner, address(this));
        }

        require(params.cptSharesIn != 0, ErrorsLib.ZeroShares());

        // slither-disable-next-line unused-return
        CORK.redeem(params.poolId, params.cptSharesIn, params.owner, params.receiver);

        // Calculate actual changes and check slippage protection.
        uint256 cptAfter = cpt.balanceOf(params.owner);
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);
        uint256 referenceAfter = referenceAsset.balanceOf(params.receiver);

        uint256 actualCptIn = cptBefore - cptAfter;
        uint256 actualReferenceOut = referenceAfter - referenceBefore;
        uint256 actualCollateralOut = collateralAfter - collateralBefore;

        require(actualCptIn <= params.cptSharesIn, ErrorsLib.SlippageExceeded());
        require(actualReferenceOut >= params.minReferenceAssetsOut, ErrorsLib.SlippageExceeded());
        require(actualCollateralOut >= params.minCollateralAssetsOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeUnwindSwap(SafeUnwindSwapParams memory params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cst;
        {
            // slither-disable-next-line unused-return
            (, address swapToken) = CORK.shares(params.poolId);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 collateralBefore = collateralAsset.balanceOf(address(this));
        uint256 cstBefore = cst.balanceOf(params.receiver);
        uint256 referenceBefore = referenceAsset.balanceOf(params.receiver);

        if (params.collateralAssetsIn == type(uint256).max) {
            params.collateralAssetsIn = collateralAsset.balanceOf(address(this));
        }

        require(params.collateralAssetsIn != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(collateralAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        CORK.unwindSwap(params.poolId, params.collateralAssetsIn, params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), 0);

        // Calculate actual changes and check slippage protection.
        uint256 collateralAfter = collateralAsset.balanceOf(address(this));
        uint256 cstAfter = cst.balanceOf(params.receiver);
        uint256 referenceAfter = referenceAsset.balanceOf(params.receiver);

        uint256 actualCollateralIn = collateralBefore - collateralAfter;
        uint256 actualCstOut = cstAfter - cstBefore;
        uint256 actualReferenceOut = referenceAfter - referenceBefore;

        require(actualCollateralIn <= params.collateralAssetsIn, ErrorsLib.SlippageExceeded());
        require(actualReferenceOut >= params.minReferenceAssetsOut, ErrorsLib.SlippageExceeded());
        require(actualCstOut >= params.minCstSharesOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeSwap(SafeSwapParams calldata params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.collateralAssetsOut != 0, ErrorsLib.ZeroAmount());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cst;
        {
            // slither-disable-next-line unused-return
            (, address swapToken) = CORK.shares(params.poolId);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 cstBefore = cst.balanceOf(address(this));
        uint256 referenceBefore = referenceAsset.balanceOf(address(this));
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);

        SafeERC20.forceApprove(referenceAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        CORK.swap(params.poolId, params.collateralAssetsOut, params.receiver);

        SafeERC20.forceApprove(referenceAsset, address(CORK), 0);

        // Calculate actual changes and check slippage protection.
        uint256 cstAfter = cst.balanceOf(address(this));
        uint256 referenceAfter = referenceAsset.balanceOf(address(this));
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);

        uint256 actualCstIn = cstBefore - cstAfter;
        uint256 actualReferenceIn = referenceBefore - referenceAfter;
        uint256 actualCollateralOut = collateralAfter - collateralBefore;

        require(actualCstIn <= params.maxCstSharesIn, ErrorsLib.SlippageExceeded());
        require(actualReferenceIn <= params.maxReferenceAssetsIn, ErrorsLib.SlippageExceeded());
        require(actualCollateralOut >= params.collateralAssetsOut, ErrorsLib.SlippageExceeded());
    }

    /// @inheritdoc ICorkAdapter
    function safeExercise(SafeExerciseParams calldata params) external onlyBundler3 onlyWhitelisted(params.poolId) {
        // Check cstShares is not 0.
        require(params.cstSharesIn != 0, ErrorsLib.ZeroShares());

        _safeExercise(
            SafeExerciseInternalParams({
                poolId: params.poolId,
                cstSharesIn: params.cstSharesIn,
                referenceAssetsIn: 0,
                receiver: params.receiver,
                minCollateralAssetsOut: params.minCollateralAssetsOut,
                maxOtherTokenIn: params.maxReferenceAssetsIn,
                deadline: params.deadline
            })
        );
    }

    /// @inheritdoc ICorkAdapter
    function safeExerciseOther(SafeExerciseOtherParams calldata params)
        external
        onlyBundler3
        onlyWhitelisted(params.poolId)
    {
        // Check referenceAssets is not 0.
        require(params.referenceAssetsIn != 0, ErrorsLib.ZeroShares());

        _safeExercise(
            SafeExerciseInternalParams({
                poolId: params.poolId,
                cstSharesIn: 0,
                referenceAssetsIn: params.referenceAssetsIn,
                receiver: params.receiver,
                minCollateralAssetsOut: params.minCollateralAssetsOut,
                maxOtherTokenIn: params.maxCstSharesIn,
                deadline: params.deadline
            })
        );
    }

    /// @inheritdoc ICorkAdapter
    function safeUnwindExercise(SafeUnwindExerciseParams calldata params)
        external
        onlyBundler3
        onlyWhitelisted(params.poolId)
    {
        require(params.cstSharesOut != 0, ErrorsLib.ZeroShares());

        _safeUnwindExercise(
            SafeUnwindExerciseInternalParams({
                poolId: params.poolId,
                cstSharesOut: params.cstSharesOut,
                referenceAssetsOut: 0,
                receiver: params.receiver,
                minOtherAssetOut: params.minReferenceAssetsOut,
                maxCollateralAssetsIn: params.maxCollateralAssetsIn,
                deadline: params.deadline
            })
        );
    }

    /// @inheritdoc ICorkAdapter
    function safeUnwindExerciseOther(SafeUnwindExerciseOtherParams calldata params)
        external
        onlyBundler3
        onlyWhitelisted(params.poolId)
    {
        require(params.referenceAssetsOut != 0, ErrorsLib.ZeroShares());

        _safeUnwindExercise(
            SafeUnwindExerciseInternalParams({
                poolId: params.poolId,
                cstSharesOut: 0,
                referenceAssetsOut: params.referenceAssetsOut,
                receiver: params.receiver,
                minOtherAssetOut: params.minCstSharesOut,
                maxCollateralAssetsIn: params.maxCollateralAssetsIn,
                deadline: params.deadline
            })
        );
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    /// @notice Either collateralAssetsOut or referenceAssetsOut MUST be 0, (not both non-zero).
    function _safeWithdraw(SafeWithdrawInternalParams memory params) internal {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());
        require(params.owner == address(this) || params.owner == initiator(), ErrorsLib.UnexpectedOwner());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cpt;
        {
            // slither-disable-next-line unused-return
            (address principalToken,) = CORK.shares(params.poolId);
            cpt = IERC20(principalToken);
        }

        // Snapshot balances before operation
        uint256 cptBefore = cpt.balanceOf(params.owner);
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);
        uint256 referenceBefore = referenceAsset.balanceOf(params.receiver);

        // slither-disable-next-line unused-return
        if (params.collateralAssetsOut != 0) {
            CORK.withdraw(params.poolId, params.collateralAssetsOut, params.owner, params.receiver);
        }
        // slither-disable-next-line unused-return
        else {
            CORK.withdrawOther(params.poolId, params.referenceAssetsOut, params.owner, params.receiver);
        }

        // Calculate actual changes and check slippage protection.
        uint256 cptAfter = cpt.balanceOf(params.owner);
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);
        uint256 referenceAfter = referenceAsset.balanceOf(params.receiver);

        uint256 actualCptIn = cptBefore - cptAfter;

        require(actualCptIn <= params.maxCptSharesIn, ErrorsLib.SlippageExceeded());

        if (params.collateralAssetsOut != 0) {
            require(collateralAfter - collateralBefore >= params.collateralAssetsOut, ErrorsLib.SlippageExceeded());
        } else {
            require(referenceAfter - referenceBefore >= params.referenceAssetsOut, ErrorsLib.SlippageExceeded());
        }
    }

    /// @notice Either cstShares or referenceAssets MUST be 0, (not both non-zero).
    function _safeExercise(SafeExerciseInternalParams memory params) internal {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cst;
        {
            // slither-disable-next-line unused-return
            (, address swapToken) = CORK.shares(params.poolId);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 cstBefore = cst.balanceOf(address(this));
        uint256 referenceBefore = referenceAsset.balanceOf(address(this));
        uint256 collateralBefore = collateralAsset.balanceOf(params.receiver);

        SafeERC20.forceApprove(referenceAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        if (params.cstSharesIn != 0) CORK.exercise(params.poolId, params.cstSharesIn, params.receiver);
        // slither-disable-next-line unused-return
        else CORK.exerciseOther(params.poolId, params.referenceAssetsIn, params.receiver);

        SafeERC20.forceApprove(referenceAsset, address(CORK), 0);

        // Calculate actual changes and check slippage protection.
        uint256 cstAfter = cst.balanceOf(address(this));
        uint256 referenceAfter = referenceAsset.balanceOf(address(this));
        uint256 collateralAfter = collateralAsset.balanceOf(params.receiver);

        uint256 actualCollateralOut = collateralAfter - collateralBefore;
        require(actualCollateralOut >= params.minCollateralAssetsOut, ErrorsLib.SlippageExceeded());

        uint256 actualCstIn = cstBefore - cstAfter;
        uint256 actualReferenceIn = referenceBefore - referenceAfter;

        if (params.cstSharesIn != 0) {
            require(actualCstIn <= params.cstSharesIn, ErrorsLib.SlippageExceeded());
            require(actualReferenceIn <= params.maxOtherTokenIn, ErrorsLib.SlippageExceeded());
        } else {
            require(actualReferenceIn <= params.referenceAssetsIn, ErrorsLib.SlippageExceeded());
            require(actualCstIn <= params.maxOtherTokenIn, ErrorsLib.SlippageExceeded());
        }
    }

    /// @notice Either cstSharesOut or referenceAssetsOut MUST be 0, (not both non-zero).
    function _safeUnwindExercise(SafeUnwindExerciseInternalParams memory params) internal {
        // slither-disable-next-line timestamp
        require(block.timestamp <= params.deadline, DeadlineExceeded());
        require(params.receiver != address(0), ErrorsLib.ZeroAddress());

        Market memory market = CORK.market(params.poolId);
        IERC20 collateralAsset = IERC20(market.collateralAsset);
        IERC20 referenceAsset = IERC20(market.referenceAsset);

        IERC20 cst;
        {
            // slither-disable-next-line unused-return
            (, address swapToken) = CORK.shares(params.poolId);
            cst = IERC20(swapToken);
        }

        // Snapshot balances before operation.
        uint256 collateralBefore = collateralAsset.balanceOf(address(this));
        uint256 cstBefore = cst.balanceOf(params.receiver);
        uint256 referenceBefore = referenceAsset.balanceOf(params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), type(uint256).max);

        // slither-disable-next-line unused-return
        if (params.cstSharesOut != 0) CORK.unwindExercise(params.poolId, params.cstSharesOut, params.receiver);
        // slither-disable-next-line unused-return
        else CORK.unwindExerciseOther(params.poolId, params.referenceAssetsOut, params.receiver);

        SafeERC20.forceApprove(collateralAsset, address(CORK), 0);

        // Calculate actual changes and check slippage protection.
        uint256 collateralAfter = collateralAsset.balanceOf(address(this));
        uint256 cstAfter = cst.balanceOf(params.receiver);
        uint256 referenceAfter = referenceAsset.balanceOf(params.receiver);

        uint256 actualCollateralIn = collateralBefore - collateralAfter;
        require(actualCollateralIn <= params.maxCollateralAssetsIn, ErrorsLib.SlippageExceeded());

        uint256 actualCstOut = cstAfter - cstBefore;
        uint256 actualReferenceOut = referenceAfter - referenceBefore;

        if (params.cstSharesOut != 0) {
            require(actualCstOut >= params.cstSharesOut, ErrorsLib.SlippageExceeded());
            require(actualReferenceOut >= params.minOtherAssetOut, ErrorsLib.SlippageExceeded());
        } else {
            require(actualReferenceOut >= params.referenceAssetsOut, ErrorsLib.SlippageExceeded());
            require(actualCstOut >= params.minOtherAssetOut, ErrorsLib.SlippageExceeded());
        }
    }
}
