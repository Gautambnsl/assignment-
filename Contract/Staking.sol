
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is ReentrancyGuard {
    // State variables
    struct Stake {
        uint256 amount;
        uint256 startTime;
    }

    mapping(address => Stake) public stakes;

    uint256 public totalStaked;
    uint256 public rewardRate;  // Reward rate per second per token staked

    address public owner;
    IERC20 public stakingToken;  // Token used for staking
    IERC20 public rewardToken;   // Token used for rewards

    // Events
    event Staked(address indexed user, uint256 amount, uint256 time);
    event Unstaked(address indexed user, uint256 amount, uint256 time);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(uint256 _rewardRate, address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        rewardRate = _rewardRate;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Stake function: Users stake their tokens
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");

        // Calculate any pending rewards before updating the stake
        uint256 pendingRewards = calculateReward(msg.sender);

        // Update the user's stake and total staked amount
        stakes[msg.sender].amount += amount;
        stakes[msg.sender].startTime = block.timestamp;
        totalStaked += amount;

        // Transfer the staking tokens from the user to the contract
        stakingToken.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, block.timestamp);

        // If there are pending rewards, transfer them to the user
        if (pendingRewards > 0) {
            rewardToken.transfer(msg.sender, pendingRewards);
            emit RewardClaimed(msg.sender, pendingRewards);
        }
    }

    // Unstake function: Users can unstake their tokens
    function unstake(uint256 amount) external nonReentrant {
        require(stakes[msg.sender].amount >= amount, "Insufficient staked balance");

        // Calculate pending rewards before updating the stake
        uint256 pendingRewards = calculateReward(msg.sender);

        // Update stake and total staked amount
        stakes[msg.sender].amount -= amount;
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].startTime = 0;
        } else {
            stakes[msg.sender].startTime = block.timestamp;  // Reset the staking time after partial unstake
        }
        totalStaked -= amount;

        // Transfer the unstaked amount back to the user
        stakingToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount, block.timestamp);

        // If there are pending rewards, transfer them to the user
        if (pendingRewards > 0) {
            rewardToken.transfer(msg.sender, pendingRewards);
            emit RewardClaimed(msg.sender, pendingRewards);
        }
    }

    // Claim rewards function: Users can claim their accumulated rewards
    function claimRewards() external nonReentrant {
        uint256 reward = calculateReward(msg.sender);

        require(reward > 0, "No rewards to claim");
        require(rewardToken.balanceOf(address(this)) >= reward, "Insufficient reward pool");

        // Reset the staking start time to the current time
        stakes[msg.sender].startTime = block.timestamp;

        // Transfer the rewards to the user
        rewardToken.transfer(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    // Calculate rewards based on staked amount and duration
    function calculateReward(address _user) public view returns (uint256) {
        Stake memory userStake = stakes[_user];
        if (userStake.amount == 0) {
            return 0;
        }

        uint256 stakingDuration = block.timestamp - userStake.startTime;
        uint256 reward = userStake.amount * stakingDuration * rewardRate  / 1e18;  // Adjusted for precision

        return reward;
    }

    // Owner can adjust the reward rate
    function adjustRewardRate(uint256 _newRate) external onlyOwner {
        rewardRate = _newRate;
    }

    // Fallback function to receive ETH
    receive() external payable {}
}
