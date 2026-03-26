// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.30;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title ERC4626Lib
/// @notice Library exposing functions to price shares of an ERC4626 vault.
library ERC4626Lib {
    /// @notice Converts `shares` into the corresponding assets on the `vault`.
    /// @param vault The vault to convert the shares to assets from
    /// @param shares The amount of shares to convert
    /// @return The amount of assets
    /// @dev When `vault` is the address zero, returns 1.
    function getAssets(IERC4626 vault, uint256 shares) internal view returns (uint256) {
        if (address(vault) == address(0)) return 1;

        return vault.convertToAssets(shares);
    }
}
