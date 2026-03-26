// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockERC20} from "./MockERC20.sol";

contract MockSwapRouter {
    address public tokenIn;
    address public tokenOut;
    uint256 public amountIn;
    uint256 public amountOut;

    // disable coverage for this contract
    function test() public view {}

    function mockPrepareSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut) external {
        tokenIn = _tokenIn;
        tokenOut = _tokenOut;
        amountIn = _amountIn;
        amountOut = _amountOut;
    }

    function swap() external {
        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        MockERC20(tokenOut).mint(msg.sender, amountOut);
    }

    function swapFail() external pure {
        revert("MockSwapRouter: swap failed");
    }
}
