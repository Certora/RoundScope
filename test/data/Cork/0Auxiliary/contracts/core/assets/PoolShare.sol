// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IPoolManager, Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {IPoolShare} from "contracts/interfaces/IPoolShare.sol";
import {ISwapRate} from "contracts/interfaces/ISwapRate.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";

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

/// @title PoolShare
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Contract for implementing Cork assets (Swap Tokens and Principal Tokens).
contract PoolShare is ERC20Burnable, ERC20Permit, Ownable, ISwapRate, IPoolShare {
    string public pairName;

    // poolId, poolManager, factory need to adhere to IPoolShare interface without extra boilerplate
    // so we keep the variable camel case rather than SCREAMING_CASE.
    MarketId public immutable poolId;

    IPoolManager public immutable poolManager;

    address public immutable factory;

    uint256 public immutable issuedAt;

    ///======================================================///
    ///=================== MODIFIERS ========================///
    ///======================================================///

    modifier onlyCorkPoolManager() {
        require(msg.sender == address(poolManager), NotCorkPoolManager());
        _;
    }

    ///======================================================///
    ///================== CONSTRUCTOR =======================///
    ///======================================================///

    constructor(IPoolShare.ConstructorParams memory params)
        ERC20(params.pairName, params.symbol)
        ERC20Permit(params.pairName)
        Ownable(params.ensOwner)
    {
        require(params.ensOwner != address(0), ZeroAddress());

        pairName = params.pairName;
        poolManager = IPoolManager(params.poolManager);
        poolId = params.poolId;

        factory = _msgSender();
        issuedAt = block.timestamp;
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc ISwapRate
    function swapRate() external view returns (uint256 rate) {
        return poolManager.swapRate(poolId);
    }

    /// @inheritdoc IPoolShare
    function getReserves() external view returns (uint256 collateralAssets, uint256 referenceAssets) {
        (collateralAssets, referenceAssets) = poolManager.assets(poolId);
    }

    /// @inheritdoc IPoolShare
    function isExpired() public view returns (bool) {
        Market memory market = poolManager.market(poolId);
        // slither-disable-next-line timestamp
        return block.timestamp >= market.expiryTimestamp;
    }

    /// @inheritdoc IPoolShare
    function expiry() external view returns (uint256) {
        Market memory market = poolManager.market(poolId);
        return market.expiryTimestamp;
    }

    ///======================================================///
    ///================== CORE FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IPoolShare
    function mint(address to, uint256 amount) public onlyCorkPoolManager {
        _mint(to, amount);
    }

    /// @inheritdoc ERC20Burnable
    function burn(uint256 amount) public override onlyCorkPoolManager {
        _burn(_msgSender(), amount);
    }

    /// @inheritdoc ERC20Burnable
    function burnFrom(address owner, uint256 amount) public override onlyCorkPoolManager {
        _spendAllowance(owner, _msgSender(), amount);
        _burn(owner, amount);
    }

    /// @inheritdoc IPoolShare
    function burnFrom(address sender, address owner, uint256 amount) public onlyCorkPoolManager {
        // we branch here because in case sender == owner, who would in the right mind give allowance
        // to themselves. so it will treat it as a regular `burn`
        if (sender != owner) _spendAllowance(owner, sender, amount);

        _burn(owner, amount);
    }

    /// @inheritdoc IPoolShare
    function transferFrom(address sender, address owner, address to, uint256 amount) public onlyCorkPoolManager {
        if (sender != owner) _spendAllowance(owner, sender, amount);

        _transfer(owner, to, amount);
    }

    ///======================================================///
    ///================= EVENT EMITTER FUNCTIONS ============///
    ///======================================================///

    /// @inheritdoc IPoolShare
    function emitDeposit(address sender, address receiver, uint256 assets, uint256 shares)
        external
        onlyCorkPoolManager
    {
        emit Deposit(sender, receiver, assets, shares);
    }

    /// @inheritdoc IPoolShare
    function emitWithdraw(address sender, address receiver, address owner, uint256 assets, uint256 shares)
        external
        onlyCorkPoolManager
    {
        emit Withdraw(sender, receiver, owner, assets, shares);
    }

    /// @inheritdoc IPoolShare
    function emitWithdrawOther(
        address sender,
        address receiver,
        address owner,
        address asset,
        uint256 assets,
        uint256 shares
    ) external onlyCorkPoolManager {
        emit WithdrawOther(sender, receiver, owner, asset, assets, shares);
    }

    /// @inheritdoc IPoolShare
    function emitDepositOther(address sender, address owner, address asset, uint256 assets, uint256 shares)
        external
        onlyCorkPoolManager
    {
        emit DepositOther(sender, owner, asset, assets, shares);
    }

    ///======================================================///
    ///=================== MAX FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IPoolShare
    function maxMint(address owner) public view returns (uint256 maxCptAndCstSharesOut) {
        maxCptAndCstSharesOut = poolManager.maxMint(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxDeposit(address owner) public view returns (uint256 maxCollateralAssetsIn) {
        maxCollateralAssetsIn = poolManager.maxDeposit(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxUnwindDeposit(address owner) public view returns (uint256 maxCollateralAssetsOut) {
        maxCollateralAssetsOut = poolManager.maxUnwindDeposit(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxUnwindMint(address owner) public view returns (uint256 maxCptAndCstSharesIn) {
        maxCptAndCstSharesIn = poolManager.maxUnwindMint(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxWithdraw(address owner) public view returns (uint256 maxCollateralAssetsOut) {
        maxCollateralAssetsOut = poolManager.maxWithdraw(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxWithdrawOther(address owner) public view returns (uint256 maxReferenceAssetsOut) {
        maxReferenceAssetsOut = poolManager.maxWithdrawOther(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxExercise(address owner) public view returns (uint256 maxCstSharesIn) {
        maxCstSharesIn = poolManager.maxExercise(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxExerciseOther(address owner) public view returns (uint256 maxReferenceAssetsIn) {
        maxReferenceAssetsIn = poolManager.maxExerciseOther(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxRedeem(address owner) public view returns (uint256 maxCptSharesIn) {
        maxCptSharesIn = poolManager.maxRedeem(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxSwap(address owner) public view returns (uint256 maxCollateralAssetsOut) {
        maxCollateralAssetsOut = poolManager.maxSwap(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxUnwindExercise(address owner) public view returns (uint256 maxCstSharesOut) {
        maxCstSharesOut = poolManager.maxUnwindExercise(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxUnwindExerciseOther(address owner) public view returns (uint256 maxReferenceAssetsOut) {
        maxReferenceAssetsOut = poolManager.maxUnwindExerciseOther(poolId, owner);
    }

    /// @inheritdoc IPoolShare
    function maxUnwindSwap(address owner) public view returns (uint256 maxCollateralAssetsIn) {
        maxCollateralAssetsIn = poolManager.maxUnwindSwap(poolId, owner);
    }

    ///======================================================///
    ///================= PREVIEW FUNCTIONS ==================///
    ///======================================================///

    /// @inheritdoc IPoolShare
    function previewExercise(uint256 cstSharesIn)
        public
        view
        returns (uint256 collateralAssetsOut, uint256 referenceAssetsIn, uint256 fee)
    {
        (collateralAssetsOut, referenceAssetsIn, fee) = poolManager.previewExercise(poolId, cstSharesIn);
    }

    /// @inheritdoc IPoolShare
    function previewExerciseOther(uint256 referenceAssetsIn)
        public
        view
        returns (uint256 collateralAssetsOut, uint256 cstSharesIn, uint256 fee)
    {
        (collateralAssetsOut, cstSharesIn, fee) = poolManager.previewExerciseOther(poolId, referenceAssetsIn);
    }

    /// @inheritdoc IPoolShare
    function previewUnwindExercise(uint256 cstSharesOut)
        public
        view
        returns (uint256 collateralAssetsIn, uint256 referenceAssetsOut, uint256 fee)
    {
        (collateralAssetsIn, referenceAssetsOut, fee) = poolManager.previewUnwindExercise(poolId, cstSharesOut);
    }

    /// @inheritdoc IPoolShare
    function previewUnwindExerciseOther(uint256 referenceAssetsOut)
        public
        view
        returns (uint256 collateralAssetsIn, uint256 cstSharesOut, uint256 fee)
    {
        (collateralAssetsIn, cstSharesOut, fee) = poolManager.previewUnwindExerciseOther(poolId, referenceAssetsOut);
    }

    /// @inheritdoc IPoolShare
    function previewDeposit(uint256 collateralAssetsIn) public view returns (uint256 cptAndCstSharesOut) {
        (cptAndCstSharesOut) = poolManager.previewDeposit(poolId, collateralAssetsIn);
    }

    /// @inheritdoc IPoolShare
    function previewSwap(uint256 collateralAssetsOut)
        public
        view
        returns (uint256 cstSharesIn, uint256 referenceAssetsIn, uint256 fee)
    {
        (cstSharesIn, referenceAssetsIn, fee) = poolManager.previewSwap(poolId, collateralAssetsOut);
    }

    /// @inheritdoc IPoolShare
    function previewRedeem(uint256 cptSharesIn)
        public
        view
        returns (uint256 referenceAssetsOut, uint256 collateralAssetsOut)
    {
        (referenceAssetsOut, collateralAssetsOut) = poolManager.previewRedeem(poolId, cptSharesIn);
    }

    /// @inheritdoc IPoolShare
    function previewUnwindDeposit(uint256 collateralAssetsOut) public view returns (uint256 cptAndCstSharesIn) {
        (cptAndCstSharesIn) = poolManager.previewUnwindDeposit(poolId, collateralAssetsOut);
    }

    /// @inheritdoc IPoolShare
    function previewUnwindSwap(uint256 collateralAssetsIn)
        public
        view
        returns (uint256 cstSharesOut, uint256 referenceAssetsOut, uint256 fee)
    {
        (cstSharesOut, referenceAssetsOut, fee) = poolManager.previewUnwindSwap(poolId, collateralAssetsIn);
    }

    /// @inheritdoc IPoolShare
    function previewMint(uint256 cptAndCstSharesOut) public view returns (uint256 collateralAssetsIn) {
        (collateralAssetsIn) = poolManager.previewMint(poolId, cptAndCstSharesOut);
    }

    /// @inheritdoc IPoolShare
    function previewUnwindMint(uint256 cptAndCstSharesIn) public view returns (uint256 collateralAssetsOut) {
        (collateralAssetsOut) = poolManager.previewUnwindMint(poolId, cptAndCstSharesIn);
    }

    /// @inheritdoc IPoolShare
    function previewWithdraw(uint256 collateralAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        (cptSharesIn, actualCollateralAssetsOut, actualReferenceAssetsOut) =
            poolManager.previewWithdraw(poolId, collateralAssetsOut);
    }

    /// @inheritdoc IPoolShare
    function previewWithdrawOther(uint256 referenceAssetsOut)
        external
        view
        returns (uint256 cptSharesIn, uint256 actualCollateralAssetsOut, uint256 actualReferenceAssetsOut)
    {
        (cptSharesIn, actualCollateralAssetsOut, actualReferenceAssetsOut) =
            poolManager.previewWithdrawOther(poolId, referenceAssetsOut);
    }
}
