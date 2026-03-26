// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "@forge-std/Test.sol";
import {EpochLib} from "@libraries/EpochLib.sol";

interface FiatTokenV1 {
    function masterMinter() external returns (address);

    function mint(address _to, uint256 _amount) external returns (bool);

    function configureMinter(address minter, uint256 minterAmount) external returns (bool);
}

// Main Fixture and configuration for preparing test environment
abstract contract InfiniFiTest is Test {
    // this function is required to ignore this file from coverage
    function test() public pure virtual {}

    // this function is to be used to deal tokens because the
    // USDC contract does not work with the standard deal function
    // as the storage is not the same as many other tokens
    // basically, USDC needs to be minted as the master minter
    // while for other tokens, we use deal from the stdCheats
    function dealToken(address token, address to, uint256 amount) public {
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        if (token == usdc) {
            // if usdc, needs to mint as the master minter
            address masterMint = FiatTokenV1(usdc).masterMinter();
            vm.prank(masterMint);
            FiatTokenV1(usdc).configureMinter(address(this), type(uint256).max);
            FiatTokenV1(usdc).mint(to, amount);
        } else {
            deal(token, to, amount);
        }
    }

    function advanceEpoch(uint32 _epochs) internal {
        vm.warp(block.timestamp + EpochLib.EPOCH * _epochs);
    }
}
