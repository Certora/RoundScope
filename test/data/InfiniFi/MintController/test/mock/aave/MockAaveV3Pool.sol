// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAaveV3Pool} from "@interfaces/aave/IAaveV3Pool.sol";
import {MockERC20} from "@test/mock/MockERC20.sol";
import {MockAToken} from "@test/mock/aave/MockAToken.sol";

contract MockAaveV3Pool is IAaveV3Pool {
    address public immutable asset;
    address public immutable aToken;

    address public addressProvider;

    constructor(address _asset, address _aToken) {
        asset = _asset;
        aToken = _aToken;
        addressProvider = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    }

    // disable coverage for this contract
    function test() public view {}

    function supply(address _asset, uint256 _amount, address _onBehalfOf, uint16) external override {
        MockERC20(_asset).transferFrom(msg.sender, aToken, _amount);
        MockAToken(aToken).mint(_onBehalfOf, _amount * 1e18 / MockAToken(aToken).multiplier());
    }

    function withdraw(address _asset, uint256 _amount, address _to) external override returns (uint256) {
        MockAToken(aToken).mockBurn(msg.sender, _amount);
        uint256 amountOut = _amount * MockAToken(aToken).multiplier() / 1e18;
        MockERC20(_asset).approveOverride(aToken, address(this), amountOut);
        MockERC20(_asset).transferFrom(aToken, _to, amountOut);
        return amountOut;
    }

    function fakeBorrow(uint256 _amount) external {
        // basically vanish some assets from the aToken contract
        MockERC20(asset).mockBurn(aToken, _amount);
    }

    function ADDRESSES_PROVIDER() external view returns (address) {
        return addressProvider;
    }

    function setAddressProvider(address _addressProvider) external {
        addressProvider = _addressProvider;
    }
}
