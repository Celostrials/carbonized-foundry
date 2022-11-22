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

    function deposit() external payable override {
        gTokenVault.depositETH{value: msg.value}(address(this));
    }

    function withdraw() external override {
        gTokenVault.withdrawAll(address(this), address(this));
    }

    function withdrawls() public override view returns (uint256 value, uint256 timestamp) {
        return gTokenVault.withdrawals(address(this)); 
    }

    function claim(address _receiver) external override {
        (uint256 value, ) = withdrawls();
        gTokenVault.claim();
        console.log(gTokenVault.asset().balanceOf(address(this)));
        console.log(address(this).balance);
        console.log(IERC20(0x471EcE3750Da237f93B8E339c536989b8978a438).balanceOf(address(this)));
        // gTokenVault.asset().transfer(_receiver, value);
    }

    function getYield() external override view returns (uint256) {
        return gTokenVault.getYield(address(this));
    }

    function getDeposit() external override view returns (uint256) {
        return IERC20(address(gTokenVault)).balanceOf(address(this));
    }

    modifier onlyCarbonizedCollection() {
        require(msg.sender == carbonizedCollection, "Carbonizer: Unauthorized caller");
        _;
    }
}
