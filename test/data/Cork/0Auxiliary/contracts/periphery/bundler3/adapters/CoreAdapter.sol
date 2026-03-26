// SPDX-License-Identifier: GPL-2.0-or-later
// Source: Morpho Bundler3
// URL: https://github.com/morpho-org/bundler3/tree/4887f33299ba6e60b54a51237b16e7392dceeb97
// Modified by: Cork Protocol Inc.
// Modification Date: 07/12/2025
// This file has been modified from the original source.

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "bundler3-oz/token/ERC20/utils/SafeERC20.sol";
import {Address} from "bundler3-oz/utils/Address.sol";
import {IBundler3} from "bundler3/interfaces/IBundler3.sol";
import {ErrorsLib} from "bundler3/libraries/ErrorsLib.sol";
import {UtilsLib} from "bundler3/libraries/UtilsLib.sol";

/// @custom:security-contact security@cork.tech
/// @notice Common contract to all Bundler3 adapters.
abstract contract CoreAdapter {
    /* IMMUTABLES */

    /// @notice The address of the Bundler3 contract.
    address public BUNDLER3;

    /* CONSTRUCTOR */

    /* MODIFIERS */

    /// @dev Prevents a function from being called outside of a bundle context.
    /// @dev Ensures the value of initiator() is correct.
    modifier onlyBundler3() {
        require(msg.sender == BUNDLER3, ErrorsLib.UnauthorizedSender());
        _;
    }

    /* FALLBACKS */

    /// @notice Native tokens are received by the adapter and should be used afterwards.
    /// @dev Allows the wrapped native contract to transfer native tokens to the adapter.
    receive() external payable virtual {}

    /* ACTIONS */

    /// @notice Transfers native assets.
    /// @param receiver The address that will receive the native tokens.
    /// @param amount The amount of native tokens to transfer. Pass `type(uint).max` to transfer the adapter's balance
    /// (this allows 0 value transfers).
    function nativeTransfer(address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = address(this).balance;
        else require(amount != 0, ErrorsLib.ZeroAmount());

        if (amount > 0) Address.sendValue(payable(receiver), amount);
    }

    /// @notice Transfers ERC20 tokens.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the adapter's balance (this
    /// allows 0 value transfers).
    function erc20Transfer(address token, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(receiver != address(this), ErrorsLib.AdapterAddress());

        if (amount == type(uint256).max) amount = IERC20(token).balanceOf(address(this));
        else require(amount != 0, ErrorsLib.ZeroAmount());

        if (amount > 0) SafeERC20.safeTransfer(IERC20(token), receiver, amount);
    }

    /* INTERNAL */

    /// @notice Returns the current initiator stored in the adapter.
    /// @dev The initiator value being non-zero indicates that a bundle is being processed.
    function initiator() internal view returns (address) {
        return IBundler3(BUNDLER3).initiator();
    }

    /// @notice Calls bundler3.reenter with an already encoded Call array.
    /// @dev Useful to skip an ABI decode-encode step when transmitting callback data.
    /// @param data An abi-encoded Call[].
    function reenterBundler3(bytes calldata data) internal {
        (bool success, bytes memory returnData) = BUNDLER3.call(bytes.concat(IBundler3.reenter.selector, data));
        if (!success) UtilsLib.lowLevelRevert(returnData);
    }
}
