// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MockNFT.sol";
import "../src/CarbonizedCollection.sol";
import "../src/CarbonizerDeployer.sol";
import "../src/Carbonizer.sol";


contract CarbonizeTest is Test {
    uint256 celoFork;
    address alice;
    address deployer;
    MockNFT public collection;
    CarbonizedCollection public carbonizedCollection;
    CarbonizerDeployer public carbonizerDeployer;

    function setUp() public {
        address gTokenVault = 0x8A1639098644A229d08F441ea45A63AE050Ee018;
        alice = address(1);
        deployer = address(2);
        vm.startPrank(deployer);
        collection = new MockNFT("Mock", "MOCK", "https://ipfs");
        carbonizedCollection = new CarbonizedCollection();
        carbonizerDeployer = new CarbonizerDeployer(gTokenVault);
        carbonizedCollection.initialize(address(collection), address(carbonizerDeployer), "Mock02", "M02", "https://forno.celo.org");
        vm.stopPrank();
        vm.deal(alice, 100 ether);
        vm.startPrank(alice);
        collection.setApprovalForAll(address(carbonizedCollection), true);
        collection.mint{value: 1 ether}(alice, 1);
    }

    function testOriginalTransfer() public {
        assertEq(collection.ownerOf(11), alice);
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertEq(collection.ownerOf(11), address(carbonizedCollection));
    }

    function testCarbonizedMint() public {
        assertEq(carbonizedCollection.exists(11), false);
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertEq(carbonizedCollection.ownerOf(11), alice);
    }

    function testCarbonizedDeposit() public {
        assertEq(carbonizedCollection.carbonizer(11), address(0));
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertTrue(carbonizedCollection.carbonizer(11) != address(0));
        assertEq(carbonizedCollection.getDeposit(11), 1 ether);
    }

    function testCarbonizedYield() public {
        carbonizedCollection.carbonize{value: 1 ether}(11);
        // add celo to stCelo 'Address' contract
        vm.deal(0x4aAD04D41FD7fd495503731C5a2579e19054C432, 100 ether);
        assertGt(carbonizedCollection.getYield(11), 0);
    }

    function testCarbonizeCarbonized() public {
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertEq(carbonizedCollection.getDeposit(11), 1 ether);
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertEq(carbonizedCollection.getDeposit(11), 2 ether);
    }
}
