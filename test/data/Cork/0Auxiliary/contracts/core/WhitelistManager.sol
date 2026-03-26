// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IPoolManager, Market, MarketId} from "contracts/interfaces/IPoolManager.sol";
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

/// @title WhitelistManager
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice External contract that manages all whitelisting logic for the Cork Protocol.
contract WhitelistManager is AccessControlUpgradeable, OwnableUpgradeable, UUPSUpgradeable, IWhitelistManager {
    bytes32 public constant CORK_CONTROLLER_ROLE = keccak256("CORK_CONTROLLER_ROLE");

    struct WhitelistManagerStorage {
        address CORK_POOL_MANAGER;
        /// @notice Global whitelist mapping
        mapping(address => bool) globalWhitelist;
        /// @notice Market-specific whitelist mapping: marketId => account => isWhitelisted
        mapping(MarketId => mapping(address => bool)) marketWhitelist;
        /// @notice Tracks whether whitelisting is enabled for each market
        mapping(MarketId => bool) marketWhitelistEnabled;
    }

    // ERC-7201 Namespaced Storage Layout.
    // keccak256(abi.encode(uint256(keccak256("cork.storage.WhitelistManager")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant _WHITELIST_MANAGER_STORAGE_POSITION =
        0x0da519c821e1a8f2910e4e535b0245b25f0e3189410accd869caacafbf3ff700;

    ///======================================================///
    ///============== INITIALIZATION FUNCTIONS ==============///
    ///======================================================///

    constructor() {
        _disableInitializers();
    }

    function initialize(address ensOwner, address admin) external initializer {
        require(ensOwner != address(0) && admin != address(0), InvalidAddress());

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Ownable_init(ensOwner);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @dev Set the Cork Pool Manager contract address.
    /// Only callable by the DEFAULT_ADMIN_ROLE.
    /// Definition is only allowed once.
    /// @param corkPoolManager The address of the Cork Pool Manager contract.
    function setOnceCorkPoolManager(address corkPoolManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(corkPoolManager != address(0), InvalidAddress());
        require(_getWhitelistManagerStorage().CORK_POOL_MANAGER == address(0), AlreadySet());

        _getWhitelistManagerStorage().CORK_POOL_MANAGER = corkPoolManager;
    }

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @inheritdoc IWhitelistManager
    // slither-disable-next-line naming-convention
    function CORK_POOL_MANAGER() external view returns (address corkPoolManager) {
        corkPoolManager = _getWhitelistManagerStorage().CORK_POOL_MANAGER;
    }

    /// @inheritdoc IWhitelistManager
    function isMarketWhitelistEnabled(MarketId marketId) external view returns (bool) {
        return _getWhitelistManagerStorage().marketWhitelistEnabled[marketId];
    }

    /// @inheritdoc IWhitelistManager
    function isGlobalWhitelisted(address account) external view returns (bool) {
        return _getWhitelistManagerStorage().globalWhitelist[account];
    }

    /// @inheritdoc IWhitelistManager
    function isMarketWhitelisted(MarketId marketId, address account) external view returns (bool) {
        return _getWhitelistManagerStorage().marketWhitelist[marketId][account];
    }

    /// @inheritdoc IWhitelistManager
    function isWhitelisted(MarketId marketId, address account) external view returns (bool) {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();

        if (!state.marketWhitelistEnabled[marketId]) return true;

        if (state.globalWhitelist[account]) return true;

        if (state.marketWhitelist[marketId][account]) return true;

        return false;
    }

    ///======================================================///
    ///================ MANAGEMENT FUNCTIONS =================///
    ///======================================================///

    /// @inheritdoc IWhitelistManager
    function addToGlobalWhitelist(address[] calldata accounts) external onlyRole(CORK_CONTROLLER_ROLE) {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), InvalidAddress());
            state.globalWhitelist[accounts[i]] = true;
            emit GlobalWhitelistAdded(accounts[i]);
        }
    }

    /// @inheritdoc IWhitelistManager
    function removeFromGlobalWhitelist(address[] calldata accounts) external onlyRole(CORK_CONTROLLER_ROLE) {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), InvalidAddress());
            state.globalWhitelist[accounts[i]] = false;
            emit GlobalWhitelistRemoved(accounts[i]);
        }
    }

    /// @inheritdoc IWhitelistManager
    function addToMarketWhitelist(MarketId marketId, address[] calldata accounts)
        external
        onlyRole(CORK_CONTROLLER_ROLE)
    {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), InvalidAddress());
            state.marketWhitelist[marketId][accounts[i]] = true;
            emit MarketWhitelistAdded(marketId, accounts[i]);
        }
    }

    /// @inheritdoc IWhitelistManager
    function removeFromMarketWhitelist(MarketId marketId, address[] calldata accounts)
        external
        onlyRole(CORK_CONTROLLER_ROLE)
    {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();

        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), InvalidAddress());
            state.marketWhitelist[marketId][accounts[i]] = false;
            emit MarketWhitelistRemoved(marketId, accounts[i]);
        }
    }

    /// @inheritdoc IWhitelistManager
    function disableMarketWhitelist(MarketId marketId) external onlyRole(CORK_CONTROLLER_ROLE) {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();
        Market memory market = IPoolManager(state.CORK_POOL_MANAGER).market(marketId);

        // isInitialized from PoolLibrary.
        if (market.referenceAsset != address(0) && market.collateralAsset != address(0)) {
            require(state.marketWhitelistEnabled[marketId], WhitelistAlreadyDisabled());
        }

        state.marketWhitelistEnabled[marketId] = false;
        emit MarketWhitelistDisabled(marketId);
    }

    /// @inheritdoc IWhitelistManager
    function activateMarketWhitelist(MarketId marketId) external onlyRole(CORK_CONTROLLER_ROLE) {
        WhitelistManagerStorage storage state = _getWhitelistManagerStorage();
        Market memory market = IPoolManager(state.CORK_POOL_MANAGER).market(marketId);
        require(market.referenceAsset == address(0) && market.collateralAsset == address(0), AlreadyInitialized()); // isInitialized from PoolLibrary
        state.marketWhitelistEnabled[marketId] = true;
        emit MarketWhitelistEnabled(marketId);
    }

    ///======================================================///
    ///================= INTERNAL FUNCTIONS =================///
    ///======================================================///

    /// @notice Authorization function for UUPS proxy upgrades.
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @notice Internal function to get the whitelist manager storage.
    function _getWhitelistManagerStorage() internal pure returns (WhitelistManagerStorage storage state) {
        // slither-disable-next-line assembly
        assembly {
            state.slot := _WHITELIST_MANAGER_STORAGE_POSITION
        }
    }
}
