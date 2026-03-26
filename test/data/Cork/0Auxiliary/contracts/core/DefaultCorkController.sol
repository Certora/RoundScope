// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IDefaultCorkController} from "contracts/interfaces/IDefaultCorkController.sol";
import {IPoolManager, MarketId} from "contracts/interfaces/IPoolManager.sol";
import {IWhitelistManager} from "contracts/interfaces/IWhitelistManager.sol";

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

/// @title DefaultCorkController
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice DefaultCorkController contract for managing pairs and controlling Cork protocol
contract DefaultCorkController is AccessControl, Ownable, Pausable, IDefaultCorkController {
    bytes32 public constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR_ROLE");
    bytes32 public constant POOL_CREATOR_ROLE = keccak256("POOL_CREATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant WHITELIST_ADDER_ROLE = keccak256("WHITELIST_ADDER_ROLE");
    bytes32 public constant WHITELIST_REMOVER_ROLE = keccak256("WHITELIST_REMOVER_ROLE");

    // slither-disable-next-line naming-convention
    IWhitelistManager public immutable WHITELIST_MANAGER;
    // slither-disable-next-line naming-convention
    IPoolManager public CORK_POOL_MANAGER;

    ///======================================================///
    ///============== INITIALIZATION FUNCTIONS ==============///
    ///======================================================///

    constructor(address ensOwner, address admin, address operationsManager, address whitelistManagerAddress)
        Ownable(ensOwner)
    {
        require(
            ensOwner != address(0) && admin != address(0) && operationsManager != address(0)
                && whitelistManagerAddress != address(0),
            InvalidAddress()
        );

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CONFIGURATOR_ROLE, operationsManager);
        _grantRole(POOL_CREATOR_ROLE, operationsManager);
        _grantRole(WHITELIST_ADDER_ROLE, operationsManager);
        _grantRole(WHITELIST_REMOVER_ROLE, operationsManager);

        WHITELIST_MANAGER = IWhitelistManager(whitelistManagerAddress);
    }

    /// @dev Set the Cork Pool Manager contract address.
    /// Only callable by the DEFAULT_ADMIN_ROLE.
    /// Definition is only allowed once.
    /// @param corkPoolManagerAddress The address of the Cork Pool Manager contract.
    function setOnceCorkPoolManager(address corkPoolManagerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(corkPoolManagerAddress != address(0), InvalidAddress());
        require(address(CORK_POOL_MANAGER) == address(0), AlreadySet());

        CORK_POOL_MANAGER = IPoolManager(corkPoolManagerAddress);
    }

    ///======================================================///
    ///=================== SETUP FUNCTIONS ==================///
    ///======================================================///

    /// @inheritdoc IDefaultCorkController
    function setTreasury(address treasuryAddress) external onlyRole(CONFIGURATOR_ROLE) {
        require(treasuryAddress != address(0), InvalidAddress());

        // updated event are emitted in this call
        CORK_POOL_MANAGER.setTreasuryAddress(treasuryAddress);
    }

    /// @inheritdoc IDefaultCorkController
    function setSharesFactory(address sharesFactory) external onlyRole(CONFIGURATOR_ROLE) {
        require(sharesFactory != address(0), InvalidAddress());

        // Events for `setSharesFactory` are emitted in this call
        CORK_POOL_MANAGER.setSharesFactory(sharesFactory);
    }

    ///======================================================///
    ///================ POOL DEPLOYMENT FUNCTIONS ===========///
    ///======================================================///

    /// @inheritdoc IDefaultCorkController
    function createNewPool(PoolCreationParams calldata params) external whenNotPaused onlyRole(POOL_CREATOR_ROLE) {
        // compute the id here to save gas
        MarketId id = MarketId.wrap(keccak256(abi.encode(params.pool)));

        if (params.isWhitelistEnabled) WHITELIST_MANAGER.activateMarketWhitelist(id);
        else WHITELIST_MANAGER.disableMarketWhitelist(id);

        CORK_POOL_MANAGER.createNewPool(params.pool);

        // update fees
        CORK_POOL_MANAGER.updateUnwindSwapFeePercentage(id, params.unwindSwapFeePercentage);
        CORK_POOL_MANAGER.updateSwapFeePercentage(id, params.swapFeePercentage);
    }

    ///======================================================///
    ///================= FEE RELATED FUNCTIONS ==============///
    ///======================================================///

    /// @inheritdoc IDefaultCorkController
    function updateUnwindSwapFeePercentage(MarketId id, uint256 newUnwindSwapFeePercentage)
        external
        onlyRole(CONFIGURATOR_ROLE)
    {
        CORK_POOL_MANAGER.updateUnwindSwapFeePercentage(id, newUnwindSwapFeePercentage);
    }

    /// @inheritdoc IDefaultCorkController
    function updateSwapFeePercentage(MarketId id, uint256 newSwapFeePercentage) external onlyRole(CONFIGURATOR_ROLE) {
        CORK_POOL_MANAGER.updateSwapFeePercentage(id, newSwapFeePercentage);
    }

    ///======================================================///
    ///================ ADMINISTRATIVE FUNCTIONS ============///
    ///======================================================///
    /// @inheritdoc IDefaultCorkController
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @inheritdoc IDefaultCorkController
    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    /// @inheritdoc IDefaultCorkController
    function pauseDeposits(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap | (1 << 0); // logical OR to enable the 1st bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseDeposits(MarketId id) external onlyRole(UNPAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap & ~(uint16(1) << 0); // logical AND NOT to disable the 1st bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function isDepositPaused(MarketId id) external view returns (bool isPaused) {
        isPaused = CORK_POOL_MANAGER.getPausedBitMap(id) & (1 << 0) != 0;
    }

    /// @inheritdoc IDefaultCorkController
    function pauseSwaps(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap | (1 << 1); // logical OR to enable the 2nd bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseSwaps(MarketId id) external onlyRole(UNPAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap & ~(uint16(1) << 1); // logical AND NOT to disable the 2nd bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function isSwapPaused(MarketId id) external view returns (bool isPaused) {
        isPaused = CORK_POOL_MANAGER.getPausedBitMap(id) & (1 << 1) != 0;
    }

    /// @inheritdoc IDefaultCorkController
    function pauseWithdrawals(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap | (1 << 2); // logical OR to enable the 3rd bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseWithdrawals(MarketId id) external onlyRole(UNPAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap & ~(uint16(1) << 2); // logical AND NOT to disable the 3rd bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function isWithdrawalPaused(MarketId id) external view returns (bool isPaused) {
        isPaused = CORK_POOL_MANAGER.getPausedBitMap(id) & (1 << 2) != 0;
    }

    /// @inheritdoc IDefaultCorkController
    function pauseUnwindDepositAndMints(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap | (1 << 3); // logical OR to enable the 4th bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseUnwindDepositAndMints(MarketId id) external onlyRole(UNPAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap & ~(uint16(1) << 3); // logical AND NOT to disable the 4th bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function isUnwindDepositAndMintPaused(MarketId id) external view returns (bool isPaused) {
        isPaused = CORK_POOL_MANAGER.getPausedBitMap(id) & (1 << 3) != 0;
    }

    /// @inheritdoc IDefaultCorkController
    function pauseUnwindSwaps(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap | (1 << 4); // logical OR to enable the 5th bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseUnwindSwaps(MarketId id) external onlyRole(UNPAUSER_ROLE) {
        uint16 currentPauseBitMap = CORK_POOL_MANAGER.getPausedBitMap(id);
        uint16 newPauseBitMap = currentPauseBitMap & ~(uint16(1) << 4); // logical AND NOT to disable the 5th bit
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function isUnwindSwapPaused(MarketId id) external view returns (bool isPaused) {
        isPaused = CORK_POOL_MANAGER.getPausedBitMap(id) & (1 << 4) != 0;
    }

    /// @inheritdoc IDefaultCorkController
    function pauseMarket(MarketId id) external onlyRole(PAUSER_ROLE) {
        uint16 newPauseBitMap = 0x1F; // 0x1F = 0001_1111 (bits 0–4 set)
        CORK_POOL_MANAGER.setPausedBitMap(id, newPauseBitMap);
    }

    /// @inheritdoc IDefaultCorkController
    function pauseAll() external onlyRole(PAUSER_ROLE) {
        CORK_POOL_MANAGER.setAllPaused(true);
    }

    /// @inheritdoc IDefaultCorkController
    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
        CORK_POOL_MANAGER.setAllPaused(false);
    }

    ///======================================================///
    ///================= WHITELIST FUNCTIONS ================///
    ///======================================================///

    /// @inheritdoc IDefaultCorkController
    function disableMarketWhitelist(MarketId marketId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        WHITELIST_MANAGER.disableMarketWhitelist(marketId);
    }

    /// @inheritdoc IDefaultCorkController
    function addToGlobalWhitelist(address[] calldata accounts) external onlyRole(WHITELIST_ADDER_ROLE) {
        WHITELIST_MANAGER.addToGlobalWhitelist(accounts);
    }

    /// @inheritdoc IDefaultCorkController
    function removeFromGlobalWhitelist(address[] calldata accounts) external onlyRole(WHITELIST_REMOVER_ROLE) {
        WHITELIST_MANAGER.removeFromGlobalWhitelist(accounts);
    }

    /// @inheritdoc IDefaultCorkController
    function addToMarketWhitelist(MarketId marketId, address[] calldata accounts)
        external
        onlyRole(WHITELIST_ADDER_ROLE)
    {
        WHITELIST_MANAGER.addToMarketWhitelist(marketId, accounts);
    }

    /// @inheritdoc IDefaultCorkController
    function removeFromMarketWhitelist(MarketId marketId, address[] calldata accounts)
        external
        onlyRole(WHITELIST_REMOVER_ROLE)
    {
        WHITELIST_MANAGER.removeFromMarketWhitelist(marketId, accounts);
    }

    /// @inheritdoc IDefaultCorkController
    function isWhitelisted(MarketId marketId, address account) external view returns (bool) {
        return WHITELIST_MANAGER.isWhitelisted(marketId, account);
    }
}
