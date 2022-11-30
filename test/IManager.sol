// SPDX-License-Identifier: Apache-2.0
// https://docs.soliditylang.org/en/v0.8.10/style-guide.html
pragma solidity 0.8.11;

interface IManager {
    function deposit() external payable;

    function withdraw(uint256 stCeloAmount) external;

    function toCelo(uint256 stCeloAmount) external view returns (uint256);

    function toStakedCelo(uint256 celoAmount) external view returns (uint256);
}
