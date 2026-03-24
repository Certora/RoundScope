pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "pkg/pool-stable/contracts/StablePool.sol";

// This is the contract that is actually verified; it may contain some helper
// methods for the spec to access internal state, or may override some of the
// more complex methods in the original contract.
contract StablePoolHarness is StablePool {
    using SafeMath for uint256;
    using StablePoolUserData for bytes;
    enum SwapKind { GIVEN_IN, GIVEN_OUT }

    uint256[] public collectedFees;
    
    constructor(
        IVault vault,
        string memory name,
        string memory symbol,
        IERC20[] memory tokens, 
        uint256 amplificationParameter,
        uint256 swapFeePercentage,
        uint256 pauseWindowDuration,
        uint256 bufferPeriodDuration,
        address owner
    ) StablePool(vault, name, symbol, tokens, amplificationParameter, 
    swapFeePercentage, pauseWindowDuration, bufferPeriodDuration, owner) {
    }

    function getTotalTokens() public view returns (uint256) {
        return _getTotalTokens();
    }

    function getAmplificationParameter_() public view returns(uint256, bool) {
        return _getAmplificationParameter();
    }

    function getJoinKind(bytes memory userData) public pure returns(StablePoolUserData.JoinKind) {
        return userData.joinKind();
    }
    
    function requireNonzero(uint256[] memory array, uint256 index) public pure {
        require(array[index] > 0);
    }

    function MIN_AMP() public pure returns (uint256) {
        return StableMath._MIN_AMP;
    }

    function MAX_AMP() public pure returns (uint256) {
        return StableMath._MAX_AMP;
    }

    function AMP_PRECISION() public pure returns (uint256) {
        return StableMath._AMP_PRECISION;
    }

    function totalTokensBalance() public view returns (uint256 total) {        
        total = _token0.balanceOf(address(this));
        total = total.add(_token1.balanceOf(address(this)));
    }
    
    function setRecoveryMode(bool enabled) public {
        _setRecoveryMode(enabled);
    }

    function onJoinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public override returns (uint256[] memory amounts, uint256[] memory fees) {
        (amounts, fees) = super.onJoinPool(
            poolId,
            sender,
            recipient,
            balances,
            lastChangeBlock,
            protocolSwapFeePercentage,
            userData
        );

        _receiveAsset(_token0, sender, amounts[0], fees[0], 0);
        _receiveAsset(_token1, sender, amounts[1], fees[1], 1);
    }


    function _receiveAsset(IERC20 token, address sender, uint256 amount, uint256 fee, uint256 id) internal {
        require(token == _token0 || token == _token1);
        token.transferFrom(sender, address(this), amount);
        if (fee > 0) { // changed so fees stay within this contract
            token.transferFrom(sender, address(this), fee);
            collectedFees[id] += fee;
        }
    }
    
    function onExitPool(
        bytes32 poolId,
        address sender,
        address recipient,
        uint256[] memory balances,
        uint256 lastChangeBlock,
        uint256 protocolSwapFeePercentage,
        bytes memory userData
    ) public override returns (uint256[] memory amounts, uint256[] memory fees) {
        (amounts, fees) = super.onExitPool(
                poolId,
                sender,
                recipient,
                balances,
                lastChangeBlock,
                protocolSwapFeePercentage,
                userData
        );

        _sendAsset(_token0, recipient, amounts[0], fees[0], 0);
        _sendAsset(_token1, recipient, amounts[1], fees[1], 1);
    }
        
    function _sendAsset(IERC20 token, address recipient, uint256 amount, uint256 fee, uint256 id) internal {
        require(token == _token0 || token == _token1);
        token.transfer(recipient, amount);
        if (fee > 0) {
            collectedFees[id] += fee;
        }
    }
}