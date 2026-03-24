// SPDX-License-Identifier: MIT
// pragma solidity ^0.8;

import "./ERC20ish.sol";

contract Staker2 {
    
    ERC20 public assets;
    ERC20 public receipts;

    function assetCount() internal view returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000a0000, 1037618708490) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000a0001, 0) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000a0004, 0) }
        return assets.balanceOf(address(this));
    }
    function receiptCount() internal view returns (uint256) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000b0000, 1037618708491) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000b0001, 0) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000b0004, 0) }
        return receipts.totalSupply();
    }
    function mulDivDown(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 res) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000c0000, 1037618708492) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000c0001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000c0005, 73) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000c6002, c) }
        res = (a * b) / c;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000002,res)}
    }
    function mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 res) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000d0000, 1037618708493) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000d0001, 3) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000d0005, 73) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000d6002, c) }
        res = ((a * b) + (c - 1)) / c;assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000003,res)}
    }

    // Stake a certain amount of assets and receive receipts in return
    function stakeA(uint256 assetAmount) public returns (uint256 receiptAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00130000, 1037618708499) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00130001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00130005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00136000, assetAmount) }
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivDown(assetAmount, receiptCount(), assetCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000004,receiptAmount)}
        }
        assets.transferFrom(msg.sender, address(this), assetAmount);
        receipts.mint(msg.sender, receiptAmount);
    }

    // Stake a certain amount of assets and receive receipts in return
    function stakeB(uint256 assetAmount) public returns (uint256 receiptAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00110000, 1037618708497) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00110001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00110005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00116000, assetAmount) }
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivUp(assetAmount, receiptCount(), assetCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000005,receiptAmount)}
        }
        assets.transferFrom(msg.sender, address(this), assetAmount);
        receipts.mint(msg.sender, receiptAmount);
    }

    // Unstake a certain amount of assets and return how many receipts are burned
    function unstakeA(uint256 assetAmount) public returns (uint256 receiptAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00100000, 1037618708496) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00100001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00100005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00106000, assetAmount) }
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivDown(assetAmount, receiptCount(), assetCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000006,receiptAmount)}
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Unstake a certain amount of assets and return how many receipts are burned
    function unstakeB(uint256 assetAmount) public returns (uint256 receiptAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000e0000, 1037618708494) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000e0001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000e0005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000e6000, assetAmount) }
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivUp(assetAmount, receiptCount(), assetCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000007,receiptAmount)}
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Burn a certain amount of receipts and receive assets in return
    function withdrawA(uint256 receiptAmount) public returns (uint256 assetAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000f0000, 1037618708495) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000f0001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000f0005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff000f6000, receiptAmount) }
        if (receiptCount() == 0) {
            assetAmount = receiptAmount;
        } else {
            assetAmount = mulDivDown(receiptAmount, assetCount(), receiptCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000008,assetAmount)}
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Burn a certain amount of receipts and receive assets in return
    function withdrawB(uint256 receiptAmount) public returns (uint256 assetAmount) {assembly ("memory-safe") { mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00120000, 1037618708498) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00120001, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00120005, 1) mstore(0xffffff6e4604afefe123321beef1b01fffffffffffffffffffffffff00126000, receiptAmount) }
        if (receiptCount() == 0) {
            assetAmount = receiptAmount;
        } else {
            assetAmount = mulDivUp(receiptAmount, assetCount(), receiptCount());assembly ("memory-safe"){mstore(0xffffff6e4604afefe123321beef1b02fffffffffffffffffffffffff00000009,assetAmount)}
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }
}