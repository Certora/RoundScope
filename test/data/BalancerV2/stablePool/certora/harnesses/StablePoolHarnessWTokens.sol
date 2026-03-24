pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "../munged/pool-stable/contracts/StablePool.sol";

// This is the contract that is actually verified; it may contain some helper
// methods for the spec to access internal state, or may override some of the
// more complex methods in the original contract.
contract StablePoolHarness is StablePool {
    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens, //@audit same token can be added twice in this array
        uint256 amplificationParameter,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    ) StablePool(vault, name, symbol, tokens, amplificationParameter, 
    swapFeePercentage, pauseWindowDuration, bufferPeriodDuration, owner) {}


    // sets recovery mode on or off
    function setRecoveryMode(bool enabled) public {
        _setRecoveryMode(enabled);
    }

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable override whenNotPaused {
        onJoinPool(
            poolId,
            sender,
            recipient,
            totalBalances,
            lastChangeBlock,
            _getProtocolSwapFeePercentage(),
            change.userData
        );
        for (uint256 i = 0; i < change.assets.length; ++i) {
            uint256 amountIn = amountsIn[i];
            _require(amountIn <= change.limits[i], Errors.JOIN_ABOVE_MAX);

            // Receive assets from the sender - possibly from Internal Balance.
            IAsset asset = change.assets[i];

            IERC20 token = _asIERC20(asset);            
            if (amount > 0) {
                token.safeTransferFrom(sender, address(this), amountIn);
            }
        }
    }


    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external override {
        pool.onExitPool(
            poolId,
            sender,
            recipient,
            totalBalances,
            lastChangeBlock,
            _getProtocolSwapFeePercentage(),
            change.userData
        );
        _processExitPoolTransfers(recipient, change, balances, amountsInOrOut, dueProtocolFeeAmounts);
    }

}

