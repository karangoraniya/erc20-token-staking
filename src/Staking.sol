// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Token Staking
/// @author Karan J Goraniya
/// @notice You can use this contract for only the most basic simulation
/// @dev All function calls are currently implemented without side effects

contract Staking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    IERC20 public stakingToken;
    IERC20 public rewardToken;

    uint256 public totalStaked;
    uint256 public rewardPool;

    uint256 private constant MONTH = 30 days;
    uint256 private constant DENOMINATOR = 100;

    struct Staker {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Staker) public stakes;

    event Stake(address indexed owner, uint256 amount, uint256 time);
    event Unstake(
        address indexed owner,
        uint256 amount,
        uint256 time,
        uint256 rewardTokens
    );
    event RewardClaimed(address indexed owner, uint256 amount);
    event RewardAdded(uint256 amount);

    constructor(
        address _stakingToken,
        address _rewardToken,
        address _owner
    ) Ownable(_owner) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    /// @notice Calculates the reward rate based on staking duration
    /// @dev Uses block.timestamp to track the time
    /// @return The reward rate percentage

    function calculateRate(address staker) private view returns (uint8) {
        uint256 time = stakes[staker].timestamp;
        if (block.timestamp - time < MONTH) {
            return 0;
        } else if (block.timestamp - time < 6 * MONTH) {
            return 5;
        } else if (block.timestamp - time < 12 * MONTH) {
            return 10;
        } else {
            return 15;
        }
    }

    /// @notice Allows users to stake ERC20 tokens
    /// @dev Transfers tokens from user to contract
    /// @param _amount The amount of tokens to stake
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0 tokens");
        require(
            stakingToken.balanceOf(msg.sender) >= _amount,
            "Insufficient balance"
        );

        if (stakes[msg.sender].amount > 0) {
            // If user has existing stake, distribute rewards first
            _distributeReward(msg.sender);
        }

        stakes[msg.sender] = Staker(_amount, block.timestamp);
        totalStaked += _amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Stake(msg.sender, _amount, block.timestamp);
    }

    /// @notice Allows users to unstake their tokens and receive rewards
    /// @dev Calculates rewards and transfers both staked tokens and rewards back to user
    /// @param _amount The amount of tokens to unstake
    function unstake(uint256 _amount) external nonReentrant {
        require(
            stakes[msg.sender].amount >= _amount,
            "Insufficient staked amount"
        );

        _distributeReward(msg.sender);

        stakes[msg.sender].amount -= _amount;
        totalStaked -= _amount;
        if (stakes[msg.sender].amount == 0) {
            delete stakes[msg.sender];
        }

        stakingToken.safeTransfer(msg.sender, _amount);

        emit Unstake(msg.sender, _amount, block.timestamp, 0); // Reward is distributed separately
    }

    /// @notice Distributes reward to a staker
    /// @dev Calculates and transfers reward tokens
    /// @param _staker The address of the staker
    function _distributeReward(address _staker) private {
        uint256 stakedAmount = stakes[_staker].amount;
        uint256 stakingDuration = block.timestamp - stakes[_staker].timestamp;
        uint256 rewardRate = calculateRate(_staker);

        uint256 reward = (stakedAmount * rewardRate * stakingDuration) /
            (MONTH * 12 * DENOMINATOR);

        if (reward > 0 && reward <= rewardPool) {
            rewardToken.safeTransfer(_staker, reward);
            rewardPool -= reward;
            emit RewardClaimed(_staker, reward);
        }

        // Reset staking timestamp
        stakes[_staker].timestamp = block.timestamp;
    }

    /// @notice Allows the owner to add rewards to the contract
    /// @param _amount The amount of reward tokens to add
    function addReward(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        rewardPool += _amount;
        emit RewardAdded(_amount);
    }

    /// @notice Allows users to claim their rewards without unstaking
    function claimRewards() external nonReentrant {
        require(stakes[msg.sender].amount > 0, "No stakes found");

        _distributeReward(msg.sender);
    }

    /// @notice Returns the current stake of a user
    /// @param _staker The address of the staker
    /// @return The amount of tokens staked and the timestamp of the stake
    function getStake(
        address _staker
    ) external view returns (uint256, uint256) {
        return (stakes[_staker].amount, stakes[_staker].timestamp);
    }

    /// @notice Returns the total amount of tokens staked
    /// @return The total amount of staked tokens
    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }

    /// @notice Returns the current reward pool balance
    /// @return The current reward pool balance
    function getRewardPool() external view returns (uint256) {
        return rewardPool;
    }
}
