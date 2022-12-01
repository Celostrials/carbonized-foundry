// SPDX-License-Identifier: Apache-2.0
// https://docs.soliditylang.org/en/v0.8.10/style-guide.html
pragma solidity 0.8.11;

import "forge-std/console.sol";
import {IManager} from "./IManager.sol";
import {IManaged} from "./IManaged.sol";
import {ILockedGold} from "./ILockedGold.sol";
import {EpochRewards} from "./EpochRewards.sol";
import {IRegistry} from "./IRegistry.sol";
import {ISortedOracles} from "./ISortedOracles.sol";
import {ImpactVault} from "./ImpactVault.sol";
import {INativeTokenImpactVault} from "./INativeTokenImpactVault.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";

/**
 * @title SpiralsCeloImpactVault
 * @author @douglasqian
 * @notice Implementation of ImpactVault on the Celo Gold token (ERC20
 *   wrapping Celo chain-native currency). Celo deposited is staked in
 *   the staked Celo (stCelo) liquid staking protocol. Withdrawing back
 *   into Celo is subject to the chain's unlocking period (72 hours)
 *   so this contract stages withdrawals until users come back to claim them.
 *   For simplicity, each user can only have 1 outstanding withdrawal at
 *   any given point in time.
 */
contract SpiralsCeloImpactVault is INativeTokenImpactVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using MathUpgradeable for uint256;

    error WithdrawOutstanding(
        address receiver,
        uint256 value,
        uint256 timestamp
    );
    error WithdrawNotReady(address receiver, uint256 timestamp);

    event Receive(address indexed sender, uint256 indexed amount);
    event Claim(address indexed receiver, uint256 indexed amount);
    event DependenciesUpdated(
        address indexed stCelo,
        address indexed manager,
        address indexed registry
    );

    struct WithdrawalInfo {
        uint256 value;
        uint256 timestamp;
    }
    mapping(address => WithdrawalInfo) public override withdrawals;

    IManager internal c_stCeloManager;
    IRegistry internal c_celoRegistry;

    /**
     * Inititalize as ImpactVault.
     *   asset -> CELO
     *   yieldAsset -> stCELO
     */
    function initialize(
        address _stCeloTokenAddress,
        address _stCeloManagerAddress,
        address _celoRegistryAddress,
        address _impactVaultManagerAddress
    ) external initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        // Ensures that `_owner` is set.
        setDependencies(
            _stCeloTokenAddress,
            _stCeloManagerAddress,
            _celoRegistryAddress
        );
        // Ensures that `_stCeloTokenAddress` has been sanitized.
        __ERC20_init("Green Celo", "gCELO");
        __ImpactVault_init(
            getGoldToken(),
            IERC20Upgradeable(_stCeloTokenAddress),
            _impactVaultManagerAddress
        );
    }

    receive() external payable {
        emit Receive(msg.sender, msg.value);
    }

    /**
     * @notice Sets dependencies on contract (stCELO contract addresses).
     */
    function setDependencies(
        address _stCeloTokenAddress,
        address _stCeloManagerAddress,
        address _celoRegistryAddress
    ) public onlyOwner {
        require(
            IManaged(_stCeloTokenAddress).manager() == _stCeloManagerAddress,
            "NON_MATCHING_STCELO_MANAGER"
        );
        require(
            IRegistry(_celoRegistryAddress).getAddressForStringOrDie(
                "Validators"
            ) != address(0),
            "INVALID_REGISTRY_ADDRESS"
        );

        c_stCeloManager = IManager(_stCeloManagerAddress);
        c_celoRegistry = IRegistry(_celoRegistryAddress);

        emit DependenciesUpdated(
            _stCeloTokenAddress,
            _stCeloManagerAddress,
            _celoRegistryAddress
        );
    }

    /**
     * DEPOSIT
     */

    /**
     * @dev Deposit CELO into stCELO Manager.
     */
    function _stake(uint256 _amount)
        internal
        virtual
        override
        returns (uint256)
    {
        // Verifying "c_stCeloManager" when dependencies are set.
        // slither-disable-next-line arbitrary-send-eth
        console.log("c_stCeloManager", address(c_stCeloManager));
        c_stCeloManager.deposit{value: _amount}();
        return _amount;
    }

    /**
     * @dev Initiates CELO withdraw from stCELO Manager contract and
     * marks outstanding withdrawal (only 1 at a time).
     */
    function _withdraw(address _receiver, uint256 _amount)
        internal
        virtual
        override
    {
        WithdrawalInfo memory withdrawInfo = withdrawals[_receiver];
        if (hasOutstandingWithdrawal(_receiver)) {
            revert WithdrawOutstanding(
                _receiver,
                withdrawInfo.value,
                withdrawInfo.timestamp
            );
        }
        // Initiate CELO withdraw by burning stCELO, will land in contract
        // automatically after 3 days.
        //
        // spCELO burned in "_beforeWithdraw" before initiating withdraw so reentrant call will fail.
        // slither-disable-next-line reentrancy-no-eth
        uint256 stCeloAmount = c_stCeloManager.toStakedCelo(_amount);
        c_stCeloManager.withdraw(stCeloAmount);

        withdrawInfo.value = _amount;
        withdrawInfo.timestamp =
            block.timestamp +
            getLockedGold().unlockingPeriod();
        withdrawals[_receiver] = withdrawInfo;
    }

    /**
     * @dev Withdraws CELO from this contract into msg.sender's address.
     */
    function claim() external virtual whenNotPaused nonReentrant {
        if (!hasWithdrawalReady(_msgSender())) {
            revert WithdrawNotReady(
                _msgSender(),
                withdrawals[_msgSender()].timestamp
            );
        }

        WithdrawalInfo memory withdrawInfo = withdrawals[_msgSender()];
        uint256 celoToWithdraw = withdrawInfo.value;

        // Reset these values transfer to protect against re-entrancy
        withdrawInfo.value = 0;
        withdrawInfo.timestamp = 0;
        withdrawals[_msgSender()] = withdrawInfo;

        // Using SafeERC20Upgradeable
        // slither-disable-next-line unchecked-transfer
        // console.log("gCELO pre", address(this).balance);
        // console.log("_msgSender()", _msgSender());
        // console.log("celoToWithdraw", celoToWithdraw);

        console.log("vault pre  ", getGoldToken().balanceOf(address(this)));
        console.log("caller pre ", getGoldToken().balanceOf(_msgSender()));
        // console.log(address(this).balance);
        // console.log(_msgSender().balance);
        console.log("getGoldToken()", address(getGoldToken()));

        bool res = getGoldToken().transfer(_msgSender(), celoToWithdraw);

        console.log("res", res);
        console.log("vault post ", getGoldToken().balanceOf(address(this)));
        console.log("caller post", getGoldToken().balanceOf(_msgSender()));
        // console.log(address(this).balance);
        // console.log(_msgSender().balance);

        // payable(_msgSender()).transfer(celoToWithdraw);
        console.log("post-transfer");
        // console.log("gCELO post", address(this).balance);

        emit Claim(_msgSender(), celoToWithdraw);
    }

    /**
     * @dev Returns true if the current user has an oustanding withdrawal.
     */
    function hasOutstandingWithdrawal(address _address)
        public
        view
        returns (bool)
    {
        return withdrawals[_address].timestamp != 0;
    }

    /**
     * @dev Returns true if current user's pending withdrawal is ready.
     */
    function hasWithdrawalReady(address _address) public view returns (bool) {
        uint256 ts = withdrawals[_address].timestamp;
        // This is ok because even if a validator messes with timestamp,
        // spCELO tokens are still being burned during withdraw to prevent
        // double-dipping on withdraws. Worst case is that someone taps
        // into the staged CELO on this contract earlier than they're supposed
        // to, but they shouldn't be able to withdraw more than their tokens
        // entitle them to. The limitation that there can only be 1 outstanding
        // withdrawal at a time and a significant unlocking period also means
        // that one would have to spoof the block time quite significantly
        // to the point where other validators would accept these blocks (~3 days).
        //
        // slither-disable-next-line timestamp
        return ts != 0 && block.timestamp >= ts;
    }

    /**
     * @dev CELO -> cUSD
     */
    function convertToUSD(uint256 _amountAsset)
        public
        view
        virtual
        override
        returns (uint256 usdAmount)
    {
        ISortedOracles sortedOracles = ISortedOracles(
            c_celoRegistry.getAddressForStringOrDie("SortedOracles")
        );
        // Returns the price of cUSD relative to Celo.
        (uint256 rateNumerator, uint256 rateDenominator) = sortedOracles
            .medianRate(address(getStableToken()));
        return _amountAsset.mulDiv(rateNumerator, rateDenominator);
    }

    /**
     * @dev stCELO -> CELO
     */
    function convertToAsset(uint256 _amountYieldAsset)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return c_stCeloManager.toCelo(_amountYieldAsset);
    }

    /**
     * @dev CELO -> stCELO
     */
    function convertToYieldAsset(uint256 _amountAsset)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return c_stCeloManager.toStakedCelo(_amountAsset);
    }

    /**
     *  @dev Returns GoldToken contract (Celo).
     */
    function getGoldToken() internal view returns (IERC20Upgradeable) {
        address goldTokenAddr = IRegistry(c_celoRegistry)
            .getAddressForStringOrDie("GoldToken");
        return IERC20Upgradeable(goldTokenAddr);
    }

    /**
     *  @dev Returns StableToken contract (cUSD).
     */
    function getStableToken() internal view returns (IERC20Upgradeable) {
        address stableTokenAddr = IRegistry(c_celoRegistry)
            .getAddressForStringOrDie("StableToken");
        return IERC20Upgradeable(stableTokenAddr);
    }

    /// @dev Returns LockedGold contract.
    function getLockedGold() internal view returns (ILockedGold) {
        address lockedGoldAddr = IRegistry(c_celoRegistry)
            .getAddressForStringOrDie("LockedGold");
        return ILockedGold(lockedGoldAddr);
    }

    /// @dev Returns EpochRewards contract.
    function getEpochRewards() internal view returns (EpochRewards) {
        address epochRewardsAddr = IRegistry(c_celoRegistry)
            .getAddressForStringOrDie("EpochRewards");
        return EpochRewards(epochRewardsAddr);
    }

    /// @dev Get APY of CELO staking from EpochRewards contract
    function getAPY() public view override returns (uint256) {
        EpochRewards epochRewards = getEpochRewards();

        (uint256 votingYieldFraction, , ) = epochRewards
            .getTargetVotingYieldParameters();
        uint256 rewardsMultiplier = epochRewards.getRewardsMultiplier();

        // Adjust to 18 decimals, CELO contracts use Fixidity (24 decimals).
        uint256 adjustedStakingAPY = (votingYieldFraction *
            365 *
            rewardsMultiplier) /
            1e24 /
            1e6;
        return adjustedStakingAPY;
    }
}
