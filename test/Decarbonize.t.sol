// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@celo-foundry/Test.sol";
import "../src/MockNFT.sol";
import "../src/CarbonizedCollection.sol";
import "../src/CarbonizerDeployer.sol";
import "../src/Carbonizer.sol";
import "../src/interface/ImpactVaultInterface.sol";

contract DecarbonizeTest is Test {
    uint256 celoFork;
    address alice;
    address bob;
    address deployer;
    ImpactVaultInterface gTokenVault;
    MockNFT public collection;
    CarbonizedCollection public carbonizedCollection;
    CarbonizerDeployer public carbonizerDeployer;

    function setUp() public {
        gTokenVault = ImpactVaultInterface(
            0x8A1639098644A229d08F441ea45A63AE050Ee018
        );
        vm.label(address(gTokenVault), "gTokenVault");
        alice = address(1);
        vm.deal(alice, 100 ether);
        deployer = address(2);
        bob = address(3);
        vm.deal(bob, 100 ether);
        vm.startPrank(deployer);
        collection = new MockNFT("Mock", "MOCK", "https://ipfs");
        carbonizedCollection = new CarbonizedCollection();
        carbonizerDeployer = new CarbonizerDeployer(address(gTokenVault));
        carbonizedCollection.initialize(
            address(collection),
            address(carbonizerDeployer),
            "Mock02",
            "M02",
            "https://forno.celo.org"
        );
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
        vm.roll(1);
        (uint256 value, uint256 timestamp) = carbonizedCollection.withdrawls(11);
        assertEq(value, 1 ether);
        assertGt(timestamp, 0);
    }

    function testFailUnfinishedDecarbonization() public {
        carbonizedCollection.startDecarbonize(11);
        carbonizedCollection.decarbonize(11);
    }

    function testDecarbonization() public {
        carbonizedCollection.startDecarbonize(11);
        (, uint256 timestamp) = carbonizedCollection.withdrawls(
            11
        );
        // Roll forward by unlock period, simulate CELO withdrawn from stCELO.
        vm.warp(timestamp);
        // check balance of alice before decarbonize
        uint256 aliceBalanceBefore = alice.balance;
        assertGt(aliceBalanceBefore, 97 ether);
        carbonizedCollection.decarbonize(11);
        // check balance of alice after decarbonize
        assertEq(alice.balance, aliceBalanceBefore + 1 ether);
        // check ownership of tokenId 11
        assertEq(collection.ownerOf(11), alice);
    }

    function testCarbonizerReuse() public {
        address carbonizerAddress = carbonizedCollection.carbonizer(11);
        carbonizedCollection.startDecarbonize(11);
        // increase time by 72 hours
        (, uint256 timestamp) = carbonizedCollection.withdrawls(
            11
        );
        vm.warp(timestamp);
        carbonizedCollection.decarbonize(11);
        // transfer tokenId 11 to bob
        collection.transferFrom(alice, bob, 11);
        vm.stopPrank();
        vm.startPrank(bob);
        carbonizedCollection.carbonize{value: 1 ether}(11);
        assertEq(carbonizedCollection.carbonizer(11), carbonizerAddress);
    }
}
