// SPDX-License-Identifier: GPL-2.0-or-later
// Source: Morpho Bundler3
// URL: https://github.com/morpho-org/bundler3/tree/4887f33299ba6e60b54a51237b16e7392dceeb97
// Modified by: Cork Protocol Inc.
// Modification Date: 07/12/2025
// This file has been modified from the original source.

pragma solidity ^0.8.28;

import {IERC4626} from "bundler3-oz/interfaces/IERC4626.sol";
import {Permit2Lib} from "bundler3-permit2/libraries/Permit2Lib.sol";
import {SafeCast160} from "bundler3-permit2/libraries/SafeCast160.sol";
import {MathRayLib} from "bundler3/libraries/MathRayLib.sol";
import {
    Address,
    CoreAdapter,
    ErrorsLib,
    IERC20,
    SafeERC20
} from "contracts/periphery/bundler3/adapters/CoreAdapter.sol";

/// @custom:security-contact security@cork.tech
/// @notice Chain agnostic adapter contract n°1.
contract GeneralAdapter1 is CoreAdapter {
    using SafeCast160 for uint256;
    using MathRayLib for uint256;

    /// CONSTRUCTOR

    /// ERC4626 ACTIONS

    /// @notice Mints shares of an ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes the given vault implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param shares The amount of vault shares to mint.
    /// @param maxSharePriceE27 The maximum amount of assets to pay to get 1 share, scaled by 1e27.
    /// @param receiver The address to which shares will be minted.
    function erc4626Mint(address vault, uint256 shares, uint256 maxSharePriceE27, address receiver)
        external
        onlyBundler3
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(shares != 0, ErrorsLib.ZeroShares());

        IERC20 underlyingToken = IERC20(IERC4626(vault).asset());
        SafeERC20.forceApprove(underlyingToken, vault, type(uint256).max);

        uint256 assets = IERC4626(vault).mint(shares, receiver);

        SafeERC20.forceApprove(underlyingToken, vault, 0);

        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Deposits underlying token in an ERC4626 vault.
    /// @dev Underlying tokens must have been previously sent to the adapter.
    /// @dev Assumes the given vault implements EIP-4626.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to deposit. Pass `type(uint).max` to deposit the adapter's balance.
    /// @param maxSharePriceE27 The maximum amount of assets to pay to get 1 share, scaled by 1e27.
    /// @param receiver The address to which shares will be minted.
    function erc4626Deposit(address vault, uint256 assets, uint256 maxSharePriceE27, address receiver)
        external
        onlyBundler3
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        IERC20 underlyingToken = IERC20(IERC4626(vault).asset());
        if (assets == type(uint256).max) assets = underlyingToken.balanceOf(address(this));

        require(assets != 0, ErrorsLib.ZeroAmount());

        SafeERC20.forceApprove(underlyingToken, vault, type(uint256).max);

        uint256 shares = IERC4626(vault).deposit(assets, receiver);

        SafeERC20.forceApprove(underlyingToken, vault, 0);

        require(assets.rDivUp(shares) <= maxSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Withdraws underlying token from an ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the adapter to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the adapter.
    /// @param vault The address of the vault.
    /// @param assets The amount of underlying token to withdraw.
    /// @param minSharePriceE27 The minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the assets are withdrawn. Can only be the adapter or the initiator.
    function erc4626Withdraw(address vault, uint256 assets, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler3
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner());
        require(assets != 0, ErrorsLib.ZeroAmount());

        uint256 shares = IERC4626(vault).withdraw(assets, receiver, owner);
        require(assets.rDivDown(shares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// @notice Redeems shares of an ERC4626 vault.
    /// @dev Assumes the given `vault` implements EIP-4626.
    /// @dev If `owner` is the initiator, they must have previously approved the adapter to spend their vault shares.
    /// Otherwise, vault shares must have been previously sent to the adapter.
    /// @param vault The address of the vault.
    /// @param shares The amount of vault shares to redeem. Pass `type(uint).max` to redeem the owner's shares.
    /// @param minSharePriceE27 The minimum number of assets to receive per share, scaled by 1e27.
    /// @param receiver The address that will receive the withdrawn assets.
    /// @param owner The address on behalf of which the shares are redeemed. Can only be the adapter or the initiator.
    function erc4626Redeem(address vault, uint256 shares, uint256 minSharePriceE27, address receiver, address owner)
        external
        onlyBundler3
    {
        require(receiver != address(0), ErrorsLib.ZeroAddress());
        require(owner == address(this) || owner == initiator(), ErrorsLib.UnexpectedOwner());

        if (shares == type(uint256).max) shares = IERC4626(vault).balanceOf(owner);

        require(shares != 0, ErrorsLib.ZeroShares());

        uint256 assets = IERC4626(vault).redeem(shares, receiver, owner);
        require(assets.rDivDown(shares) >= minSharePriceE27, ErrorsLib.SlippageExceeded());
    }

    /// CALLBACKS

    /// ACTIONS

    /// PERMIT2 ACTIONS

    /// @notice Transfers with Permit2.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function permit2TransferFrom(address token, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address initiator = initiator();
        if (amount == type(uint256).max) amount = IERC20(token).balanceOf(initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        Permit2Lib.PERMIT2.transferFrom(initiator, receiver, amount.toUint160(), token);
    }

    /// TRANSFER ACTIONS

    /// @notice Transfers ERC20 tokens from the initiator.
    /// @notice Initiator must have given sufficient allowance to the Adapter to spend their tokens.
    /// @param token The address of the ERC20 token to transfer.
    /// @param receiver The address that will receive the tokens.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function erc20TransferFrom(address token, address receiver, uint256 amount) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address initiator = initiator();
        if (amount == type(uint256).max) amount = IERC20(token).balanceOf(initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        // slither-disable-next-line arbitrary-send-erc20
        SafeERC20.safeTransferFrom(IERC20(token), initiator, receiver, amount);
    }

    /// WRAPPED NATIVE TOKEN ACTIONS

    /// INTERNAL FUNCTIONS
}
