// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Fixture} from "@test/Fixture.t.sol";
import {MockFarm} from "@test/mock/MockFarm.sol";
import {CoreRoles} from "@libraries/CoreRoles.sol";
import {FarmTypes} from "@libraries/FarmTypes.sol";
import {ManualRebalancer} from "@integrations/farms/movement/ManualRebalancer.sol";

contract ManualRebalancerUnitTest is Fixture {
    function setUp() public override {
        super.setUp();

        farm1.mockProfit(100e6);
    }

    function testInitialState() public view {
        assertEq(farm1.assets(), 100e6, "Error: Farm1's assets does not reflect the correct amount for initial state");
        assertEq(farm2.assets(), 0, "Error: Farm2's assets does not reflect the correct amount for initial state");

        assertEq(manualRebalancer.cooldown(), 4 hours, "Error: manualRebalancer.cooldown() incorrect");
    }

    function testSingleMovement() public {
        // check access control
        vm.expectRevert("UNAUTHORIZED");
        manualRebalancer.singleMovement(address(farm1), address(farm2), 30e6);

        vm.prank(msig);
        manualRebalancer.singleMovement(address(farm1), address(farm2), 30e6);

        assertEq(
            farm1.assets(), 70e6, "Error: Farm1's assets does not reflect the correct amount after single movement"
        );
        assertEq(
            farm2.assets(), 30e6, "Error: Farm2's assets does not reflect the correct amount after single movement"
        );

        farm1.setLiquidityPercentage(0.5e18); // 50% liquid => 35e6

        // move max liquidity
        vm.prank(msig);
        manualRebalancer.singleMovement(address(farm1), address(farm2), 0);

        assertEq(
            farm1.assets(), 35e6, "Error: Farm1's assets does not reflect the correct amount after single movement"
        );
        assertEq(
            farm2.assets(), 65e6, "Error: Farm2's assets does not reflect the correct amount after single movement"
        );

        // move max assets
        vm.prank(msig);
        manualRebalancer.singleMovement(address(farm1), address(farm2), type(uint256).max);

        assertEq(farm1.assets(), 0, "Error: Farm1's assets does not reflect the correct amount after single movement");
        assertEq(
            farm2.assets(), 100e6, "Error: Farm2's assets does not reflect the correct amount after single movement"
        );
    }

    function testBatchMovementShouldRevertIf0Movements() public {
        address[] memory fromFarms = new address[](0);
        address[] memory toFarms = new address[](0);
        uint256[] memory amounts = new uint256[](0);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.EmptyInput.selector));
        manualRebalancer.batchMovement(fromFarms, toFarms, amounts);
    }

    function testBatchMovementsShouldRevertIfMismatchLengths() public {
        address[] memory fromFarms = new address[](1);
        address[] memory toFarms = new address[](2);
        uint256[] memory amounts = new uint256[](1);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.InvalidInput.selector));
        manualRebalancer.batchMovement(fromFarms, toFarms, amounts);

        fromFarms = new address[](2);
        toFarms = new address[](1);
        amounts = new uint256[](2);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.InvalidInput.selector));
        manualRebalancer.batchMovement(fromFarms, toFarms, amounts);

        fromFarms = new address[](2);
        toFarms = new address[](2);
        amounts = new uint256[](1);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.InvalidInput.selector));
        manualRebalancer.batchMovement(fromFarms, toFarms, amounts);
    }

    function testBatchMovements() public {
        address[] memory fromFarms = new address[](2);
        address[] memory toFarms = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        // first movement: farm1 -> illiquidFarm1 for 30e6
        fromFarms[0] = address(farm1);
        toFarms[0] = address(illiquidFarm1);
        amounts[0] = 30e6;

        // second movement: farm1 -> farm2 for 10e6
        fromFarms[1] = address(farm1);
        toFarms[1] = address(farm2);
        amounts[1] = 10e6;

        uint256 farm1AssetsBefore = farm1.assets();
        uint256 farm2AssetsBefore = farm2.assets();
        uint256 illiquidFarm1AssetsBefore = illiquidFarm1.assets();

        vm.prank(msig);
        manualRebalancer.batchMovement(fromFarms, toFarms, amounts);

        assertEq(farm1.assets(), farm1AssetsBefore - 40e6);
        assertEq(farm2.assets(), farm2AssetsBefore + 10e6);
        assertEq(illiquidFarm1.assets(), illiquidFarm1AssetsBefore + 30e6);
    }

    function testFarmWhitelist() public {
        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.InvalidFarm.selector, address(this)));
        manualRebalancer.singleMovement(address(farm1), address(this), 123);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.InvalidFarm.selector, address(this)));
        manualRebalancer.singleMovement(address(this), address(farm2), 456);
    }

    function testAssetCompatibility() public {
        // add a new farm with a different asset
        MockFarm farm3 = new MockFarm(address(core), address(iusd));
        address[] memory farms = new address[](1);
        farms[0] = address(farm3);
        vm.prank(governorAddress);
        farmRegistry.enableAsset(address(iusd));
        vm.prank(parametersAddress);
        farmRegistry.addFarms(FarmTypes.MATURITY, farms);

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.IncompatibleAssets.selector));
        manualRebalancer.singleMovement(address(farm1), address(farm3), 42);
    }

    function testDeactivate() public {
        vm.prank(governorAddress);
        core.revokeRole(CoreRoles.FARM_MANAGER, address(manualRebalancer));

        vm.prank(msig);
        vm.expectRevert("UNAUTHORIZED");
        manualRebalancer.singleMovement(address(farm1), address(farm2), 42);
    }

    function testPauseUnpause() public {
        vm.prank(guardianAddress);
        manualRebalancer.pause();

        vm.prank(msig);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        manualRebalancer.singleMovement(address(farm1), address(farm2), 50e6);

        vm.prank(guardianAddress);
        manualRebalancer.unpause();

        testSingleMovement();
    }

    function testBatchMovementsWithCooldown() public {
        address[] memory fromFarms = new address[](2);
        address[] memory toFarms = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        // first movement: farm1 -> illiquidFarm1 for 30e6
        fromFarms[0] = address(farm1);
        toFarms[0] = address(illiquidFarm1);
        amounts[0] = 30e6;

        // second movement: farm1 -> farm2 for 10e6
        fromFarms[1] = address(farm1);
        toFarms[1] = address(farm2);
        amounts[1] = 10e6;

        uint256 farm1AssetsBefore = farm1.assets();
        uint256 farm2AssetsBefore = farm2.assets();
        uint256 illiquidFarm1AssetsBefore = illiquidFarm1.assets();

        vm.prank(keeper);
        manualRebalancer.batchMovementWithCooldown(fromFarms, toFarms, amounts);

        assertEq(farm1.assets(), farm1AssetsBefore - 40e6);
        assertEq(farm2.assets(), farm2AssetsBefore + 10e6);
        assertEq(illiquidFarm1.assets(), illiquidFarm1AssetsBefore + 30e6);

        // test cooldown
        vm.expectRevert(abi.encodeWithSelector(ManualRebalancer.CooldownNotElapsed.selector));
        vm.prank(keeper);
        manualRebalancer.batchMovementWithCooldown(fromFarms, toFarms, amounts);
    }

    function testSetCooldown() public {
        vm.prank(parametersAddress);
        manualRebalancer.setCooldown(1 days);
        assertEq(manualRebalancer.cooldown(), 1 days, "Error: manualRebalancer.cooldown() not set");
    }
}
