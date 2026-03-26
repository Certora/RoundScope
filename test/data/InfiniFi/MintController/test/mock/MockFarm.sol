// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockERC20} from "@test/mock/MockERC20.sol";

import {Farm} from "@integrations/Farm.sol";

contract MockVault {
    address public assetToken;

    constructor(address _assetToken) {
        assetToken = _assetToken;
    }

    function withdraw(uint256 amount) external {
        MockERC20(assetToken).transfer(msg.sender, amount);
    }
}

contract MockFarm is Farm {
    // this function is required to ignore this file from coverage
    function test() public pure {}

    uint256 public liquidityPercentage = 1e18; // default = 100% liquid
    uint256 public _maturity = 0;
    MockVault private vault;

    constructor(address _core, address _assetToken) Farm(_core, _assetToken) {
        vault = new MockVault(_assetToken);
    }

    function assets() public view override returns (uint256) {
        return MockERC20(assetToken).balanceOf(address(vault));
    }

    function liquidity() external view override returns (uint256) {
        return assets() * liquidityPercentage / 1e18;
    }

    function setLiquidityPercentage(uint256 _liquidityPercentage) external {
        liquidityPercentage = _liquidityPercentage;
    }

    function _deposit(uint256 assetsToDeposit) internal override {
        MockERC20(assetToken).transfer(address(vault), assetsToDeposit);
    }

    function _withdraw(uint256 amount, address to) internal override {
        vault.withdraw(amount);
        require(MockERC20(assetToken).transfer(to, amount), "MockFarm: transfer failed");
    }

    function maturity() public view returns (uint256) {
        return _maturity == 0 ? block.timestamp : _maturity;
    }

    function mockSetMaturity(uint256 __maturity) external {
        _maturity = __maturity;
    }

    function mockProfit(uint256 amount) external {
        MockERC20(assetToken).mint(address(vault), amount);
    }

    function mockLoss(uint256 amount) external {
        MockERC20(assetToken).mockBurn(address(vault), amount);
    }
}
