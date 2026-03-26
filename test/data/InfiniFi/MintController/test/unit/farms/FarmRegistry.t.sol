// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Fixture} from "@test/Fixture.t.sol";
import {FarmTypes} from "@libraries/FarmTypes.sol";
import {FarmRegistry} from "@integrations/FarmRegistry.sol";

contract FarmRegistryUnitTest is Fixture {
    address public assetToken = makeAddr("mockAssetToken");

    function isFarmOfType(address _farm, uint256 _type) internal view returns (bool) {
        return farmRegistry.isFarmOfType(_farm, _type);
    }

    function _testAddFarm(uint256 _type) internal {
        address[] memory farms = new address[](1);
        farms[0] = address(this);
        vm.expectRevert("UNAUTHORIZED");
        farmRegistry.addFarms(_type, farms);

        vm.prank(parametersAddress);
        vm.expectRevert(abi.encodeWithSelector(FarmRegistry.AssetNotEnabled.selector, address(this), assetToken));
        farmRegistry.addFarms(_type, farms);

        assetToken = address(usdc);

        vm.prank(parametersAddress);
        farmRegistry.addFarms(_type, farms);

        vm.expectRevert(abi.encodeWithSelector(FarmRegistry.FarmAlreadyAdded.selector, farms[0]));
        vm.prank(parametersAddress);
        farmRegistry.addFarms(_type, farms);
    }

    function _testRemoveFarm(uint256 _type) internal {
        address[] memory farms = new address[](1);
        farms[0] = farmRegistry.getTypeFarms(_type)[0];
        vm.expectRevert("UNAUTHORIZED");
        farmRegistry.removeFarms(_type, farms);

        vm.prank(parametersAddress);
        farmRegistry.removeFarms(_type, farms);

        vm.expectRevert(abi.encodeWithSelector(FarmRegistry.FarmNotFound.selector, farms[0]));
        vm.prank(parametersAddress);
        farmRegistry.removeFarms(_type, farms);
    }

    function assertEqualFarms(address[] memory _farms) internal view {
        assertEq(_farms.length, 6, "Error: FarmRegistry's farms length is not correct");
        assertEq(_farms[0], address(mintController), "Error: FarmRegistry's farms does not reflect correct address");
        assertEq(_farms[1], address(redeemController), "Error: FarmRegistry's farms does not reflect correct address");
        assertEq(_farms[2], address(farm1), "Error: FarmRegistry's farms does not reflect correct address");
        assertEq(_farms[3], address(farm2), "Error: FarmRegistry's farms does not reflect correct address");
        assertEq(_farms[4], address(illiquidFarm1), "Error: FarmRegistry's farms does not reflect correct address");
        assertEq(_farms[5], address(illiquidFarm2), "Error: FarmRegistry's farms does not reflect correct address");
    }

    function assertEqualTypeFarms(
        address[] memory _liquidFarms,
        address[] memory _maturityFarms,
        address[] memory _protocolFarms
    ) internal view {
        assertEq(_liquidFarms.length, 2, "Liquid farms must have 2 elements");
        assertEq(_maturityFarms.length, 2, "Maturity farms must have 2 elements");
        assertEq(_protocolFarms.length, 2, "Protocol farms must have 2 elements");

        assertEq(_protocolFarms[0], address(mintController), "First protocol farm must be mint controller");
        assertEq(_protocolFarms[1], address(redeemController), "Second protocol farm must be redeem controller");
        assertEq(_liquidFarms[0], address(farm1), "First liquid farm must be farm1");
        assertEq(_liquidFarms[1], address(farm2), "Second liquid farm must be farm2");
        assertEq(_maturityFarms[0], address(illiquidFarm1), "First maturity farm must be illiquidFarm1");
        assertEq(_maturityFarms[1], address(illiquidFarm2), "Second maturity farm must be illiquidFarm2");
    }

    function testGetFarms() public view {
        address[] memory farms = farmRegistry.getFarms();
        assertEqualFarms(farms);
    }

    function testGetTypeFarms() public view {
        address[] memory liquidFarms = farmRegistry.getTypeFarms(FarmTypes.LIQUID);
        address[] memory maturityFarms = farmRegistry.getTypeFarms(FarmTypes.MATURITY);
        address[] memory protocolFarms = farmRegistry.getTypeFarms(FarmTypes.PROTOCOL);

        assertEqualTypeFarms(liquidFarms, maturityFarms, protocolFarms);
    }

    function testGetAssetFarms() public view {
        address[] memory assetFarms = farmRegistry.getAssetFarms(address(usdc));
        address[] memory noAssetFarms = farmRegistry.getAssetFarms(address(assetToken));

        assertEq(assetFarms.length, 6, "usdc should have 6 farms");
        assertEq(noAssetFarms.length, 0, "unknown asset should have 0 farms");

        assertEqualFarms(assetFarms);
    }

    function testGetAssetTypeFarms() public view {
        address[] memory liquidFarms = farmRegistry.getAssetTypeFarms(address(usdc), FarmTypes.LIQUID);
        address[] memory maturityFarms = farmRegistry.getAssetTypeFarms(address(usdc), FarmTypes.MATURITY);
        address[] memory protocolFarms = farmRegistry.getAssetTypeFarms(address(usdc), FarmTypes.PROTOCOL);

        assertEqualTypeFarms(liquidFarms, maturityFarms, protocolFarms);
    }

    function testIsFarm() public view {
        assertEq(farmRegistry.isFarm(address(mintController)), true, "Error: FarmRegistry's should be a farm");
        assertEq(farmRegistry.isFarm(address(redeemController)), true, "Error: FarmRegistry's should be a farm");
        assertEq(farmRegistry.isFarm(address(farm1)), true, "Error: FarmRegistry's should be a farm");
        assertEq(farmRegistry.isFarm(address(farm2)), true, "Error: FarmRegistry's should be a farm");
        assertEq(farmRegistry.isFarm(address(this)), false, "Error: FarmRegistry's should not be a farm");
    }

    function testIsFarmOfType() public view {
        assertEq(
            isFarmOfType(address(mintController), FarmTypes.PROTOCOL), true, "Mint controller should be a protocol farm"
        );
        assertEq(
            isFarmOfType(address(redeemController), FarmTypes.PROTOCOL),
            true,
            "Redeem controller should be a protocol farm"
        );
        assertEq(isFarmOfType(address(farm1), FarmTypes.LIQUID), true, "farm1 should be liquid farm");
        assertEq(isFarmOfType(address(farm2), FarmTypes.LIQUID), true, "farm2 should be liquid farm");
        assertEq(
            isFarmOfType(address(this), FarmTypes.LIQUID), false, "Error: FarmRegistry's should not be a liquid farm"
        );
        assertEq(isFarmOfType(address(illiquidFarm1), FarmTypes.MATURITY), true, "illiquidFarm1 should be liquid farm");
        assertEq(isFarmOfType(address(illiquidFarm2), FarmTypes.MATURITY), true, "illiquidFarm2 should be liquid farm");
    }

    function testAddFarms(uint256 farmType) public {
        farmType = bound(farmType, 0, 2);
        _testAddFarm(farmType);
    }

    function testRemoveFarms(uint256 farmType) public {
        farmType = bound(farmType, 0, 2);
        _testRemoveFarm(farmType);
    }

    function testEnableAsset() public {
        address _asset = makeAddr("newAsset");
        vm.expectRevert("UNAUTHORIZED");
        farmRegistry.enableAsset(_asset);

        vm.prank(governorAddress);
        vm.expectRevert(abi.encodeWithSelector(FarmRegistry.AssetAlreadyEnabled.selector, address(usdc)));
        farmRegistry.enableAsset(address(usdc));

        vm.prank(governorAddress);
        farmRegistry.enableAsset(_asset);
    }

    function testDisableAsset() public {
        vm.expectRevert("UNAUTHORIZED");
        farmRegistry.disableAsset(address(usdc));

        vm.prank(governorAddress);
        farmRegistry.disableAsset(address(usdc));

        vm.prank(governorAddress);
        vm.expectRevert(abi.encodeWithSelector(FarmRegistry.AssetNotFound.selector, address(usdc)));
        farmRegistry.disableAsset(address(usdc));
    }
}
