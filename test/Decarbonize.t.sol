// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MockNFT.sol";
import "../src/CarbonizedCollection.sol";
import "../src/CarbonizerDeployer.sol";
import "../src/Carbonizer.sol";


contract DecarbonizeTest is Test {
    uint256 celoFork;
    address alice;
    address bob;
    address deployer;
    MockNFT public collection;
    CarbonizedCollection public carbonizedCollection;
    CarbonizerDeployer public carbonizerDeployer;

    function setUp() public {
        address gTokenVault = 0x8A1639098644A229d08F441ea45A63AE050Ee018;
        celoFork = vm.createFork("https://forno.celo.org");
        vm.selectFork(celoFork);
        alice = address(1);
        vm.deal(alice, 100 ether);
        deployer = address(2);
        bob = address(3);
        vm.deal(bob, 100 ether);
        vm.startPrank(deployer);
        collection = new MockNFT("Mock", "MOCK", "https://ipfs");
        carbonizedCollection = new CarbonizedCollection();
        carbonizerDeployer = new CarbonizerDeployer(gTokenVault);
        carbonizedCollection.initialize(address(collection), address(carbonizerDeployer), "Mock02", "M02", "https://forno.celo.org");
        vm.stopPrank();
        vm.startPrank(bob);
        collection.setApprovalForAll(address(carbonizedCollection), true);
        vm.stopPrank();
        vm.startPrank(alice);
        collection.setApprovalForAll(address(carbonizedCollection), true);
        collection.mint{value: 1 ether}(alice, 1);
        carbonizedCollection.carbonize{value: 1 ether}(11);
    }

    function testStartDecarbonization() public {
        carbonizedCollection.startDecarbonize(11);
        (uint256 value, uint256 timestamp) = carbonizedCollection.withdrawls(11);
        assertGt(value, 0);
        assertGt(timestamp, 0);
    }

    function testFailUnfinishedDecarbonization() public {
        carbonizedCollection.startDecarbonize(11);
        carbonizedCollection.decarbonize(11);
    }

    function testDecarbonization() public {
        // check balance of alice
        carbonizedCollection.startDecarbonize(11);
        // increase time by 72 hours
        carbonizedCollection.decarbonize(11);
        // check balance of alice
        // check ownership of tokenId 11
    }

    function testCarbonizerReuse() public {
        address carbonizerAddress = carbonizedCollection.carbonizer(11);
        carbonizedCollection.startDecarbonize(11);
        // increase time by 72 hours
        carbonizedCollection.decarbonize(11);
        // transfer tokenId 11 to bob
        collection.transferFrom(alice, bob, 11);
        vm.stopPrank();
        vm.startPrank(bob);
        carbonizedCollection.carbonize(11);
        assertEq(carbonizedCollection.carbonizer(11), carbonizerAddress);
    }
}