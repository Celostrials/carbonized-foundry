// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interface/ImpactVaultInterface.sol";
import "./interface/ICarbonizer.sol";
import "forge-std/console.sol";

/// @title Carbonizer
/// @author Bridger Zoske
contract Carbonizer is Ownable, ICarbonizer {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public carbonizedCollection;
    ImpactVaultInterface public gTokenVault;

    constructor(address _gTokenVaultAddress, address _carbonizedCollection) {
        gTokenVault = ImpactVaultInterface(_gTokenVaultAddress);
        carbonizedCollection = _carbonizedCollection;
    }

    receive() external payable {}

    function deposit() external payable override {
        console.log("pre-deposit");
        console.log("gTokenVault inside", address(gTokenVault));
        gTokenVault.depositETH{value: msg.value}(address(this));
        console.log("post-deposit");
    }

    function withdraw() external override {
        console.log("pre withdraw", gTokenVault.balanceOf(address(this)));
        gTokenVault.withdrawAll(address(this), address(this));
        console.log("post withdraw", gTokenVault.balanceOf(address(this)));
    }

    function withdrawls()
        public
        view
        override
        returns (uint256 value, uint256 timestamp)
    {
        return gTokenVault.withdrawals(address(this));
    }

    function claim(address _receiver) external override {
        (uint256 value, uint256 timestamp) = withdrawls();
        console.log("value", value);
        console.log("timestamp", timestamp);
        // console.log("block.timestamp", block.timestamp);
        // console.log("pre-claim", address(this).balance);
        console.log("carbonizer", address(this));
        console.log("address(gTokenVault)", address(gTokenVault));
        console.log(
            "hasWithdrawalReady",
            gTokenVault.hasWithdrawalReady(address(this))
        );
        gTokenVault.claim();
        // console.log("post-claim", address(this).balance);
        // gTokenVault.asset().transfer(_receiver, value);
    }

    function getYield() external view override returns (uint256) {
        return gTokenVault.getYield(address(this));
    }

    function getDeposit() external view override returns (uint256) {
        return IERC20(address(gTokenVault)).balanceOf(address(this));
    }

    modifier onlyCarbonizedCollection() {
        require(
            msg.sender == carbonizedCollection,
            "Carbonizer: Unauthorized caller"
        );
        _;
    }
}
