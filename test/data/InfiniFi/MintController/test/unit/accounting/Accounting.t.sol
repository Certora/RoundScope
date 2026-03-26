// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Fixture} from "@test/Fixture.t.sol";
import {FarmTypes} from "@libraries/FarmTypes.sol";
import {Accounting} from "@finance/Accounting.sol";

contract AccountingUnitTest is Fixture {
    function setUp() public override {
        super.setUp();
    }

    function testSetOracleShouldRevertIfNotOracleManager() public {
        vm.expectRevert("UNAUTHORIZED");
        accounting.setOracle(address(usdc), address(0));
    }

    function testSetOracle() public {
        vm.prank(oracleManagerAddress);
        accounting.setOracle(address(usdc), address(0));
        assertEq(accounting.oracle(address(usdc)), address(0));
    }

    function testTotalGetters() public {
        assertEq(accounting.totalAssets(address(usdc)), 0);
        assertEq(accounting.totalAssetsValue(), 0);

        farm1.mockProfit(1000e6);
        assertEq(accounting.totalAssetsValue(), 1000e18, "Error: Total Assets Value is not correct"); // $, all
        assertEq(
            accounting.totalAssetsValueOf(FarmTypes.LIQUID), 1000e18, "Error: Total Liquid Assets Value is not correct"
        ); // $, liquid
        assertEq(
            accounting.totalAssetsValueOf(FarmTypes.MATURITY), 0, "Error: Total Illiquid Assets Value is not correct"
        ); // $, illiquid
        assertEq(accounting.totalAssets(address(usdc)), 1000e6, "Error: Total Assets is not correct"); // USDC, all
        assertEq(
            accounting.totalAssetsOf(address(usdc), FarmTypes.LIQUID),
            1000e6,
            "Error: Total Liquid Assets is not correct"
        ); // USDC, liquid
        assertEq(
            accounting.totalAssetsOf(address(usdc), FarmTypes.MATURITY),
            0,
            "Error: Total Illiquid Assets is not correct"
        ); // USDC, illiquid

        illiquidFarm1.mockProfit(2000e6);
        assertEq(accounting.totalAssetsValue(), 3000e18, "Error: Total Assets Value is not correct"); // $, all
        assertEq(
            accounting.totalAssetsValueOf(FarmTypes.LIQUID), 1000e18, "Error: Total Liquid Assets Value is not correct"
        ); // $, liquid
        assertEq(
            accounting.totalAssetsValueOf(FarmTypes.MATURITY),
            2000e18,
            "Error: Total Illiquid Assets Value is not correct"
        ); // $, illiquid
        assertEq(accounting.totalAssets(address(usdc)), 3000e6, "Error: Total Assets is not correct"); // USDC, all
        assertEq(
            accounting.totalAssetsOf(address(usdc), FarmTypes.LIQUID),
            1000e6,
            "Error: Total Liquid Assets is not correct"
        ); // USDC, liquid
        assertEq(
            accounting.totalAssetsOf(address(usdc), FarmTypes.MATURITY),
            2000e6,
            "Error: Total Illiquid Assets is not correct"
        ); // USDC, illiquid
    }
}
