// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20, IERC20, ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract Mock4626 is ERC4626 {
    uint256 public sharePrice;

    // disable coverage for this contract
    function test() public view {}

    constructor(address _receiptToken)
        ERC20(
            string.concat("Mock 4626 ", ERC20(_receiptToken).name()),
            string.concat("m4626_", ERC20(_receiptToken).symbol())
        )
        ERC4626(IERC20(_receiptToken))
    {}

    function mockSharePrice(uint256 _price) public {
        sharePrice = _price;
    }

    /// if _share is 1e6 then if sharePrice is 1.15e18 it will returns
    /// 1e6 * 1.15e18 / 1e18 = 1.15e6
    function convertToAssets(uint256 _shares) public view override returns (uint256) {
        return _shares * sharePrice / 1e18;
    }
}
