// SPDX-License-Identifier: Apache-2.0
// https://github.com/celo-org/celo-monorepo/tree/master/packages/protocol/contracts/governance/interfaces/ILockedGold.sol
pragma solidity 0.8.11;

interface ILockedGold {
    function incrementNonvotingAccountBalance(address, uint256) external;

    function decrementNonvotingAccountBalance(address, uint256) external;

    function getAccountTotalLockedGold(address) external view returns (uint256);

    function getAccountNonvotingLockedGold(address)
        external
        view
        returns (uint256);

    function unlockingPeriod() external view returns (uint256);

    function getTotalLockedGold() external view returns (uint256);

    function getPendingWithdrawal(address, uint256)
        external
        view
        returns (uint256, uint256);

    function getPendingWithdrawals(address)
        external
        view
        returns (uint256[] memory, uint256[] memory);

    function getTotalPendingWithdrawals(address)
        external
        view
        returns (uint256);

    function lock() external payable;

    function unlock(uint256) external;

    function relock(uint256, uint256) external;

    function withdraw(uint256) external;

    function slash(
        address account,
        uint256 penalty,
        address reporter,
        uint256 reward,
        address[] calldata lessers,
        address[] calldata greaters,
        uint256[] calldata indices
    ) external;

    function isSlasher(address) external view returns (bool);
}
