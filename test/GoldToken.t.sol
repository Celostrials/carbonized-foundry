// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@celo-foundry/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DecarbonizeTest is Test {
    uint256 celoFork;
    address alice;
    address bob;
    // address deployer;
    // ImpactVaultInterface gTokenVault;
    // ImpactVaultInterface gTokenVault2;
    // MockNFT public collection;
    // CarbonizedCollection public carbonizedCollection;
    // CarbonizerDeployer public carbonizerDeployer;
    IERC20 goldToken = IERC20(0x471EcE3750Da237f93B8E339c536989b8978a438);

    function setUp() public {
        celoFork = vm.createFork("https://forno.celo.org");
        alice = address(1);
        bob = address(2);
    }

    function test_basic() public {
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        console.log("alice balance", alice.balance);
        console.log("bob   balance", bob.balance);

        console.log("alice goldToken", goldToken.balanceOf(alice));
        console.log("bob   goldToken", goldToken.balanceOf(bob));

        changePrank(alice);
        payable(bob).send(1 ether);
        console.log("------------------------------------------");

        console.log("alice goldToken", goldToken.balanceOf(alice));
        console.log("bob   goldToken", goldToken.balanceOf(bob));

        console.log("alice balance", alice.balance);
        console.log("bob   balance", bob.balance);
    }

    function test_reverse() public {
        // deal(address(goldToken), alice, 1 ether);
        // deal(address(goldToken), bob, 1 ether);
        vm.selectFork(celoFork);

        alice = 0xE1C46D6e7D44a446E2981A7C96F0cf9A9b097AF5;
        bob = 0x70b720713341CD390527f973083864b2A9B1560F;

        console.log("alice balance", alice.balance);
        console.log("bob   balance", bob.balance);

        console.log("alice goldToken", goldToken.balanceOf(alice));
        console.log("bob   goldToken", goldToken.balanceOf(bob));

        changePrank(alice);
        goldToken.transfer(bob, 1 ether);
        console.log("------------------------------------------");

        console.log("alice goldToken", goldToken.balanceOf(alice));
        console.log("bob   goldToken", goldToken.balanceOf(bob));

        console.log("alice balance", alice.balance);
        console.log("bob   balance", bob.balance);
    }
}
