// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MockERC20 is ERC20, ERC20Permit, ERC20Burnable {
    // this function is required to ignore this file from coverage
    function test() public pure virtual {}

    constructor(string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {}

    uint8 internal _decimals = 18;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setDecimals(uint8 dec) public {
        _decimals = dec;
    }

    function mint(address account, uint256 amount) public returns (bool) {
        _mint(account, amount);
        return true;
    }

    function mockBurn(address account, uint256 amount) public returns (bool) {
        _burn(account, amount);
        return true;
    }

    function approveOverride(address owner, address spender, uint256 amount) public {
        _approve(owner, spender, amount);
    }
}
