// SPDX-License-Identifier: GPL-2.0-or-later
// Source: Morpho Bundler3
// URL: https://github.com/morpho-org/bundler3/tree/4887f33299ba6e60b54a51237b16e7392dceeb97
// Modified by: Cork Protocol Inc.
// Modification Date: 07/12/2025
// This file has been modified from the original source.

pragma solidity ^0.8.28;

import {
    ErrorsLib,
    GeneralAdapter1,
    IERC20,
    Permit2Lib,
    SafeCast160
} from "contracts/periphery/bundler3/adapters/GeneralAdapter1.sol";
import {IPermit2, ISignatureTransfer} from "permit2/src/interfaces/IPermit2.sol";

/// @title GeneralAdapter
/// @custom:security-contact security@cork.tech
/// @notice Chain agnostic adapter contract n°1.
contract GeneralAdapter is GeneralAdapter1 {
    using SafeCast160 for uint256;

    /// IMMUTABLES

    /// @dev The address of the PERMIT2 contract.
    // slither-disable-next-line naming-convention
    IPermit2 public immutable PERMIT2;

    /// CONSTRUCTOR

    constructor() {
        PERMIT2 = IPermit2(address(Permit2Lib.PERMIT2));
    }

    /// ERC4626 ACTIONS

    /// CALLBACKS

    /// ACTIONS

    /// PERMIT2 ACTIONS

    /// @notice Transfers with Permit2.
    /// @param permit The permit which contains the address of the ERC20 token to transfer, the maximum amount, the nonce, and the deadline.
    /// @param signature The signature to verify
    /// @param receiver The address that will receive the tokens. `onlyBundler3` ensures that this originated from the initiator.
    /// @param amount The amount of token to transfer. Pass `type(uint).max` to transfer the initiator's balance.
    function permit2TransferFromWithPermit(
        ISignatureTransfer.PermitTransferFrom calldata permit,
        bytes calldata signature,
        address receiver,
        uint256 amount
    ) external onlyBundler3 {
        require(receiver != address(0), ErrorsLib.ZeroAddress());

        address initiator = initiator();
        if (amount == type(uint256).max) amount = IERC20(permit.permitted.token).balanceOf(initiator);

        require(amount != 0, ErrorsLib.ZeroAmount());

        PERMIT2.permitTransferFrom(
            permit,
            ISignatureTransfer.SignatureTransferDetails({to: receiver, requestedAmount: amount}),
            initiator,
            signature
        );
    }

    /// TRANSFER ACTIONS

    /// WRAPPED NATIVE TOKEN ACTIONS

    /// INTERNAL FUNCTIONS
}
