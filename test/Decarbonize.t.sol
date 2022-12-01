// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@celo-foundry/Test.sol";
import "forge-std/console.sol";
import "../src/MockNFT.sol";
import "../src/CarbonizedCollection.sol";
import "../src/CarbonizerDeployer.sol";
import "../src/Carbonizer.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/interface/ImpactVaultInterface.sol";
import "./CELO.sol";

contract DecarbonizeTest is Test {
    uint256 celoFork;
    address alice;
    address bob;
    address deployer;
    ImpactVaultInterface gTokenVault;
    // ImpactVaultInterface gTokenVault2;
    MockNFT public collection;
    CarbonizedCollection public carbonizedCollection;
    CarbonizerDeployer public carbonizerDeployer;

    event Claim(address indexed receiver, uint256 indexed amount);

    function setUp() public {
        // celoFork = vm.createFork("https://forno.celo.org");
        // vm.selectFork(celoFork);

        // SpiralsCeloImpactVault gCELO = new SpiralsCeloImpactVault();
        // console.log("pre-init");
        // gCELO.initialize(
        //     0xC668583dcbDc9ae6FA3CE46462758188adfdfC24,
        //     0x0239b96D10a434a56CC9E09383077A0490cF9398,
        //     0x000000000000000000000000000000000000ce10,
        //     0x23D1916EB055778D10CC0A1c558B7EeEeCe815b5
        // );
        // console.log("post-init");
        gTokenVault = ImpactVaultInterface(
            0x8A1639098644A229d08F441ea45A63AE050Ee018
        );
        // console.log("gTokenVault deployed to", address(gCELO));
        // gTokenVault = ImpactVaultInterface(address(gCELO));
        // vm.deal(address(gCELO), 10 ether);
        // console.log("B");

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
        // console.log("C");

        vm.stopPrank();
        vm.startPrank(bob);
        collection.setApprovalForAll(address(carbonizedCollection), true);
        vm.stopPrank();
        vm.startPrank(alice);
        collection.setApprovalForAll(address(carbonizedCollection), true);
        // console.log("D");

        collection.mint{value: 1 ether}(alice, 1);
        // console.log("E");

        carbonizedCollection.carbonize{value: 1 ether}(11);
        // console.log("F");
    }

    // function testStartDecarbonization() public {
    //     carbonizedCollection.startDecarbonize(11);
    //     vm.roll(1);
    //     (uint256 value, uint256 timestamp) = carbonizedCollection.withdrawls(11);
    //     assertEq(value, 1 ether);
    //     assertGt(timestamp, 0);
    // }

    // function testFailUnfinishedDecarbonization() public {
    //     carbonizedCollection.startDecarbonize(11);
    //     carbonizedCollection.decarbonize(11);
    // }

    function testDecarbonization() public {
        assertGt(alice.balance, 97 ether);

        console.log("entered test");
        carbonizedCollection.startDecarbonize(11);
        (uint256 value, uint256 timestamp) = carbonizedCollection.withdrawls(
            11
        );
        // Roll forward by unlock period, simulate CELO withdrawn from stCELO.
        vm.deal(address(gTokenVault), 100 ether);
        vm.warp(timestamp + 1);
        // console.log(address(gTokenVault).balance);
        // uint256 pre = address(gTokenVault).balance;

        address carbonizer = carbonizedCollection.carbonizer(11);

        uint256 pre = address(carbonizer).balance;
        // console.log(value);
        vm.expectEmit(true, true, false, false, address(gTokenVault));

        // We emit the event we expect to see.
        emit Claim(carbonizedCollection.carbonizer(11), 1 ether);

        console.log("owner", gTokenVault.owner());
        // console.log(gTokenVault.getAPY());

        carbonizedCollection.decarbonize(11);
        // (value, timestamp) = carbonizedCollection.withdrawls(11);
        console.log("pre ", pre);
        console.log("post", address(carbonizer).balance);
        // console.log(value);
        // assertEq(carbonizedCollection.carbonizer(11).balance, 1 ether);
        // check balance of alice
        // check ownership of tokenId 11
    }

    // function testCarbonizerReuse() public {
    //     address carbonizerAddress = carbonizedCollection.carbonizer(11);
    //     carbonizedCollection.startDecarbonize(11);
    //     // increase time by 72 hours
    //     carbonizedCollection.decarbonize(11);
    //     // transfer tokenId 11 to bob
    //     collection.transferFrom(alice, bob, 11);
    //     vm.stopPrank();
    //     vm.startPrank(bob);
    //     carbonizedCollection.carbonize(11);
    //     assertEq(carbonizedCollection.carbonizer(11), carbonizerAddress);
    // }

    function test_transfer() public {
        address goldToken = 0x8A1639098644A229d08F441ea45A63AE050Ee018;
        IERC20 celoERC20 = IERC20(goldToken);

        address user1 = 0xE1C46D6e7D44a446E2981A7C96F0cf9A9b097AF5;
        address user2 = 0x25F61cA8075c52e6726B5d14e13631303b37b9Aa;

        console.log("a");
        deal(goldToken, user1, 1 ether);
        console.log("b");

        console.log("alice pre", celoERC20.balanceOf(user1));
        console.log("bob pre  ", celoERC20.balanceOf(user2));

        changePrank(user1);
        bool res = celoERC20.transfer(user2, 1 ether);

        console.log("res", res);
        console.log("alice pre", celoERC20.balanceOf(user1));
        console.log("bob pre  ", celoERC20.balanceOf(user2));
    }

    function test_simple() public {
        address goldToken = 0x8A1639098644A229d08F441ea45A63AE050Ee018;
        ImpactVaultInterface gCELO = ImpactVaultInterface(goldToken);

        // address user1 = 0xE1C46D6e7D44a446E2981A7C96F0cf9A9b097AF5;
        // address user2 = 0x25F61cA8075c52e6726B5d14e13631303b37b9Aa;

        deal(alice, 1 ether);
        deal(goldToken, 0);

        changePrank(alice);
        gCELO.depositETH{value: 1 ether}(alice);

        gCELO.withdrawAll(alice, alice);
        (uint256 value, uint256 timestamp) = gCELO.withdrawals(alice);
        console.log("value (ether)", value / 1 ether);
        console.log("timestamp diff ", timestamp - block.timestamp);

        vm.warp(timestamp);

        deal(goldToken, 1);

        console.log("alice pre ", alice.balance);
        console.log("gCELO pre ", goldToken.balance);

        gCELO.claim();

        console.log("alice post", alice.balance);
        console.log("gCELO post", goldToken.balance);
    }
}
