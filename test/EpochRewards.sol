// SPDX-License-Identifier: Apache-2.0
// https://docs.soliditylang.org/en/v0.8.10/style-guide.html
pragma solidity >=0.8.0;

abstract contract EpochRewards {
    uint256 public targetValidatorEpochPayment;

    function getRewardsMultiplier() external view virtual returns (uint256);

    function getTargetVotingYieldParameters()
        external
        view
        virtual
        returns (
            uint256,
            uint256,
            uint256
        );
}
