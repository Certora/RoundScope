// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import {IErrors} from "contracts/interfaces/IErrors.sol";
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

/// @title IWhitelistManager
/// @author Cork Team
/// @custom:security-contact security@cork.tech
/// @notice Interface for the WhitelistManager contract that handles all whitelisting logic.
interface IWhitelistManager is IErrors {
    ///======================================================///
    ///======================= EVENTS =======================///
    ///======================================================///
    /// @notice Emitted when an account is added to the global whitelist.
    event GlobalWhitelistAdded(address indexed account);

    /// @notice Emitted when an account is removed from the global whitelist.
    event GlobalWhitelistRemoved(address indexed account);

    /// @notice Emitted when an account is added to a market-specific whitelist.
    event MarketWhitelistAdded(MarketId indexed poolId, address account);

    /// @notice Emitted when an account is removed from a market-specific whitelist.
    event MarketWhitelistRemoved(MarketId indexed poolId, address account);

    /// @notice Emitted when a market's whitelist is disabled.
    event MarketWhitelistDisabled(MarketId indexed poolId);

    /// @notice Emitted when a market's whitelist is enabled.
    event MarketWhitelistEnabled(MarketId indexed poolId);

    ///======================================================///
    ///================== VIEW FUNCTIONS ====================///
    ///======================================================///

    /// @notice Get the address of the CorkPoolManager contract.
    /// @return corkPoolManager The address of the CorkPoolManager contract.
    /// slither-disable-next-line naming-convention
    function CORK_POOL_MANAGER() external view returns (address corkPoolManager);

    /// @notice Checks if a market has whitelisting enabled.
    /// @param poolId The market identifier.
    /// @return True if whitelisting is enabled, false if disabled.
    function isMarketWhitelistEnabled(MarketId poolId) external view returns (bool);

    /// @notice Checks if an account is on the global whitelist.
    /// @param account The account to check.
    /// @return True if the account is on global whitelist, false otherwise.
    function isGlobalWhitelisted(address account) external view returns (bool);

    /// @notice Checks if an account is on a market-specific whitelist.
    /// @param poolId The market identifier.
    /// @param account The account to check.
    /// @return True if the account is on market whitelist, false otherwise.
    function isMarketWhitelisted(MarketId poolId, address account) external view returns (bool);

    ///======================================================///
    ///================ MANAGEMENT FUNCTIONS =================///
    ///======================================================///

    /// @notice Adds accounts to the global whitelist.
    /// @param accounts Array of accounts to add.
    function addToGlobalWhitelist(address[] calldata accounts) external;

    /// @notice Removes accounts from the global whitelist.
    /// @param accounts Array of accounts to remove.
    function removeFromGlobalWhitelist(address[] calldata accounts) external;

    /// @notice Adds accounts to a market-specific whitelist.
    /// @param poolId The market identifier.
    /// @param accounts Array of accounts to add.
    function addToMarketWhitelist(MarketId poolId, address[] calldata accounts) external;

    /// @notice Removes accounts from a market-specific whitelist.
    /// @param poolId The market identifier.
    /// @param accounts Array of accounts to remove.
    function removeFromMarketWhitelist(MarketId poolId, address[] calldata accounts) external;

    /// @notice Disables whitelisting for a specific market (cannot be re-enabled).
    /// @param poolId The market identifier.
    function disableMarketWhitelist(MarketId poolId) external;

    /// @notice Activates the whitelist status for a market during market creation.
    /// @param poolId The market identifier.
    function activateMarketWhitelist(MarketId poolId) external;

    ///======================================================///
    ///================= ENFORCEMENT FUNCTIONS ==============///
    ///======================================================///

    /// @notice Checks if an account is whitelisted for a specific market (for enforcement).
    /// @param poolId The market identifier.
    /// @param account The account to check.
    /// @return True if the account is whitelisted, false otherwise.
    function isWhitelisted(MarketId poolId, address account) external view returns (bool);
}
