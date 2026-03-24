// SPDX-License-Identifier: MIT
// pragma solidity ^0.8;

import "./ERC20ish.sol";

contract Staker2 {
    
    ERC20 public assets;
    ERC20 public receipts;

    function assetCount() internal view returns (uint256) {
        return assets.balanceOf(address(this));
    }
    function receiptCount() internal view returns (uint256) {
        return receipts.totalSupply();
    }
    function mulDivDown(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 res) {
        res = (a * b) / c;
    }
    function mulDivUp(uint256 a, uint256 b, uint256 c) internal pure returns (uint256 res) {
        res = ((a * b) + (c - 1)) / c;
    }

    // Stake a certain amount of assets and receive receipts in return
    function stakeA(uint256 assetAmount) public returns (uint256 receiptAmount) {
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivDown(assetAmount, receiptCount(), assetCount());
        }
        assets.transferFrom(msg.sender, address(this), assetAmount);
        receipts.mint(msg.sender, receiptAmount);
    }

    // Stake a certain amount of assets and receive receipts in return
    function stakeB(uint256 assetAmount) public returns (uint256 receiptAmount) {
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivUp(assetAmount, receiptCount(), assetCount());
        }
        assets.transferFrom(msg.sender, address(this), assetAmount);
        receipts.mint(msg.sender, receiptAmount);
    }

    // Unstake a certain amount of assets and return how many receipts are burned
    function unstakeA(uint256 assetAmount) public returns (uint256 receiptAmount) {
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivDown(assetAmount, receiptCount(), assetCount());
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Unstake a certain amount of assets and return how many receipts are burned
    function unstakeB(uint256 assetAmount) public returns (uint256 receiptAmount) {
        if (assetCount() == 0) {
            receiptAmount = assetAmount;
        } else {
            receiptAmount = mulDivUp(assetAmount, receiptCount(), assetCount());
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Burn a certain amount of receipts and receive assets in return
    function withdrawA(uint256 receiptAmount) public returns (uint256 assetAmount) {
        if (receiptCount() == 0) {
            assetAmount = receiptAmount;
        } else {
            assetAmount = mulDivDown(receiptAmount, assetCount(), receiptCount());
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }

    // Burn a certain amount of receipts and receive assets in return
    function withdrawB(uint256 receiptAmount) public returns (uint256 assetAmount) {
        if (receiptCount() == 0) {
            assetAmount = receiptAmount;
        } else {
            assetAmount = mulDivUp(receiptAmount, assetCount(), receiptCount());
        }
        assets.transfer(msg.sender, assetAmount);
        receipts.burn(msg.sender, receiptAmount);
    }
}