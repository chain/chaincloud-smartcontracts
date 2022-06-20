//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract NodeStakingPool is Initializable, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeCastUpgradeable for uint256;

    uint256 private constant ACCUMULATED_MULTIPLIER = 1e12;

    uint256 public constant _MAXIMUM_DELAY_DURATION = 35 days; // maximum 35 days delay

    // Info of each user.
    struct NodeStakingUserInfo {
        uint256 stakeTime; // next reward block
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 pendingReward; // Reward but not harvest
        // uint256 boostRewardAppliciableAt; // the time user can have reward after first deposit
        // uint256 boostReward; // reward from staking block to nextRewardBlock
        //
        //   pending reward = (user.amount * accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a  Here's what happens:
        //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    IERC20 public stakeToken; // Address of LP token contract.
    uint256 public stakeTokenSupply; // Total lp tokens deposited to this
    uint256 public totalRunningNode; // Total lp tokens deposited to this
    uint256 public lastRewardBlock; // Last block number that rewards distribution occurs.
    uint256 public accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
    uint256 public delayDuration; // The duration user need to wait when withdraw.
    uint256 public requireStakeAmount; // stake amount need for user to run node
    uint256 public nextRewardBlock; // the lastest time that reward stop calculate and user can be withdraw

    struct NodeStakingPendingWithdrawal {
        uint256 amount;
        uint256 applicableAt;
    }

    // The reward token!
    IERC20 public rewardToken;
    // Total rewards for each block.
    uint256 public rewardPerBlock;
    // The reward distribution address
    address public rewardDistributor;
    // Allow emergency withdraw feature
    bool public allowEmergencyWithdraw;
    // Info of each user that stakes LP tokens.
    mapping(address => NodeStakingUserInfo) public userInfo;
    // The block number when rewards mining starts.
    uint256 public startBlockNumber;
    // The block number when rewards mining ends.
    uint256 public endBlockNumber;
    // withdraw period
    uint256 public withdrawPeriod;
    // withdraw period
    uint256 public lockupDuration;
    // the weight of provider to earn reward
    mapping(address => uint256) public userRunningNode;
    // Info of pending withdrawals.
    mapping(address => NodeStakingPendingWithdrawal) public pendingWithdrawals;

    event NodeStakingDeposit(address user, uint256 amount);
    event NodeStakingWithdraw(address user, uint256 amount);
    event NodeStakingPendingWithdraw(address user, uint256 amount);
    event NodeStakingEmergencyWithdraw(address user, uint256 amount);
    event NodeStakingRewardsHarvested(address user, uint256 amount);
    event NodeStakingClaimBoostReward(address user, uint256 amount);

    /**
     * @notice Initialize the contract, get called in the first time deploy
     * @param _rewardToken the reward token address
     * @param _rewardPerBlock the number of reward tokens that got unlocked each block
     * @param _startBlock the block number when farming start
     */
    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        IERC20 _stakeToken,
        uint256 _delayDuration
    ) public initializer {
        __Ownable_init();

        require(address(_rewardToken) != address(0), "NodeStakingPool: invalid reward token address");
        require(_startBlock < _endBlock, "NodeStakingPool: invalid start block or end block");

        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlockNumber = _startBlock;
        endBlockNumber = _endBlock;

        lastRewardBlock = block.number > startBlockNumber ? block.number : startBlockNumber;
        stakeToken = _stakeToken;
        stakeTokenSupply = 0;
        totalRunningNode = 0;
        requireStakeAmount = 0;
        lastRewardBlock = lastRewardBlock;
        accRewardPerShare = 0;
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Update the given pool's reward allocation point. Can only be called by the owner.
     * @param _delayDuration the time user need to wait when withdraw
     */
    function setPool(uint256 _delayDuration) external onlyOwner {
        require(_delayDuration <= _MAXIMUM_DELAY_DURATION, "NodeStakingPool: delay duration is too long");
        updatePool();

        delayDuration = _delayDuration;
    }

    /**
     * @notice Set the reward distributor. Can only be called by the owner.
     * @param _rewardDistributor the reward distributor
     */
    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        require(_rewardDistributor != address(0), "NodeStakingPool: invalid reward distributor");
        rewardDistributor = _rewardDistributor;
    }

    /**
     * @notice Set the end block number. Can only be called by the owner.
     */
    function setEndBlock(uint256 _endBlockNumber) external onlyOwner {
        require(_endBlockNumber > block.number, "NodeStakingPool: invalid reward distributor");
        endBlockNumber = _endBlockNumber;
    }

    /**
     * @notice Return time multiplier over the given _from to _to block.
     * @param _from the number of starting block
     * @param _to the number of ending block
     */
    function timeMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (endBlockNumber > 0 && _to > endBlockNumber) {
            return endBlockNumber > _from ? endBlockNumber - _from : 0;
        }
        return _to - _from;
    }

    function getNextRewardBlock() public view returns (uint256) {
        uint256 currBlockNumber = block.timestamp;
        if (currBlockNumber > endBlockNumber) {
            currBlockNumber = endBlockNumber;
        }

        uint256 duration = currBlockNumber - startBlockNumber;

        // tmp is the times that done lockupDuration
        uint256 tmp = duration / (lockupDuration + withdrawPeriod);
        return tmp * lockupDuration + withdrawPeriod;
    }

    function stakingTime(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_from >= _to) return 0;
        if (endBlockNumber > 0 && _to > endBlockNumber) {
            return endBlockNumber > _from ? endBlockNumber - _from : 0;
        }

        uint256 duration = _to - _from;

        // tmp is the times that done lockupDuration
        uint256 tmp = duration / (lockupDuration + withdrawPeriod);

        return tmp * lockupDuration;
    }

    /**
     * @notice Update number of reward per block
     * @param _rewardPerBlock the number of reward tokens that got unlocked each block
     */
    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        updatePool();
        rewardPerBlock = _rewardPerBlock;
    }

    /**
     * @notice View function to see pending rewards on frontend.
     * @param _user the address of the user
     */
    function pendingReward(address _user) public view returns (uint256) {
        NodeStakingUserInfo storage user = userInfo[_user];

        uint256 _accRewardPerShare = accRewardPerShare;
        if (block.number > lastRewardBlock && stakeTokenSupply != 0) {
            uint256 multiplier = stakingTime(lastRewardBlock, block.number);
            uint256 poolReward = multiplier * rewardPerBlock;
            _accRewardPerShare = _accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / stakeTokenSupply);
        }
        return
            user.pendingReward +
            (((requireStakeAmount * userRunningNode[_user] * accRewardPerShare) / ACCUMULATED_MULTIPLIER) -
                user.rewardDebt);
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (stakeTokenSupply == 0) {
            lastRewardBlock = block.number;
            return;
        }
        nextRewardBlock = getNextRewardBlock();
        uint256 multiplier = stakingTime(lastRewardBlock, block.number);
        uint256 poolReward = multiplier * rewardPerBlock;
        accRewardPerShare = (accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / stakeTokenSupply));
        lastRewardBlock = nextRewardBlock - withdrawPeriod;
    }

    /**
     * @notice Deposit LP tokens to the farm for reward allocation.
     * @param _count count to deposit
     */
    function deposit(uint256 _count) external {
        uint256 _amount = _count * requireStakeAmount;

        NodeStakingUserInfo storage user = userInfo[msg.sender];
        user.stakeTime = block.number;
        user.amount = user.amount + _amount;
        stakeTokenSupply = stakeTokenSupply + _amount;
        stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit NodeStakingDeposit(msg.sender, _amount);
    }

    function enableAddress(address _user) external onlyOwner {
        NodeStakingUserInfo storage user = userInfo[_user];
        updatePool();
        uint256 pending = ((requireStakeAmount * userRunningNode[_user] * accRewardPerShare) / ACCUMULATED_MULTIPLIER) -
            user.rewardDebt;
        // TODO: calculate reward from lastRewardBlock to current block and add to pending reward
        uint256 tempRewardDebt = rewardInTimeForUser(totalRunningNode, 1, block.number - lastRewardBlock);

        user.pendingReward = user.pendingReward + pending;
        user.rewardDebt =
            tempRewardDebt +
            (requireStakeAmount * userRunningNode[_user] * accRewardPerShare) /
            ACCUMULATED_MULTIPLIER;

        totalRunningNode = totalRunningNode + 1;
        userRunningNode[_user] = userRunningNode[_user] + 1;
    }

    function disableAddress(address _user) external onlyOwner {
        NodeStakingUserInfo storage user = userInfo[_user];
        updatePool();
        uint256 pending = ((requireStakeAmount * userRunningNode[_user] * accRewardPerShare) / ACCUMULATED_MULTIPLIER) -
            user.rewardDebt;
        user.pendingReward = user.pendingReward + pending;
        user.rewardDebt = (requireStakeAmount * userRunningNode[_user] * accRewardPerShare) / ACCUMULATED_MULTIPLIER;
        totalRunningNode = totalRunningNode - 1;
        userRunningNode[_user] = userRunningNode[_user] - 1;
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _count count to withdraw
     * @param _harvestReward whether the user want to claim the rewards or not
     */
    function withdraw(uint256 _count, bool _harvestReward) external {
        require(isInWithdrawTime(userInfo[msg.sender].stakeTime), "NodeStakingPool: not in withdraw time");

        uint256 amount = _count * requireStakeAmount;

        _withdraw(amount, _harvestReward);

        if (delayDuration == 0) {
            stakeToken.safeTransfer(address(msg.sender), amount);
            emit NodeStakingWithdraw(msg.sender, amount);
            return;
        }

        NodeStakingPendingWithdrawal storage pendingWithdraw = pendingWithdrawals[msg.sender];
        pendingWithdraw.amount = pendingWithdraw.amount + amount;
        pendingWithdraw.applicableAt = block.number + delayDuration;
    }

    /**
     * @notice Claim pending withdrawal
     */
    function claimPendingWithdraw() external {
        NodeStakingPendingWithdrawal storage pendingWithdraw = pendingWithdrawals[msg.sender];
        uint256 amount = pendingWithdraw.amount;
        require(amount > 0, "NodeStakingPool: nothing is currently pending");
        require(pendingWithdraw.applicableAt <= block.number, "NodeStakingPool: not released yet");
        delete pendingWithdrawals[msg.sender];
        stakeToken.safeTransfer(address(msg.sender), amount);
        emit NodeStakingWithdraw(msg.sender, amount);
    }

    /**
     * @notice Update allowance for emergency withdraw
     * @param _shouldAllow should allow emergency withdraw or not
     */
    function setAllowEmergencyWithdraw(bool _shouldAllow) external onlyOwner {
        allowEmergencyWithdraw = _shouldAllow;
    }

    /**
     * @notice Withdraw without caring about rewards. EMERGENCY ONLY.
     */
    function emergencyWithdraw() external {
        require(allowEmergencyWithdraw, "NodeStakingPool: emergency withdrawal is not allowed yet");
        NodeStakingUserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        stakeTokenSupply = stakeTokenSupply - amount;
        stakeToken.safeTransfer(address(msg.sender), amount);
        emit NodeStakingEmergencyWithdraw(msg.sender, amount);
    }

    /**
     * @notice Harvest proceeds msg.sender
     */
    function claimReward() public returns (uint256) {
        updatePool();
        NodeStakingUserInfo storage user = userInfo[msg.sender];
        uint256 totalPending = pendingReward(msg.sender);

        user.pendingReward = 0;
        user.rewardDebt =
            (requireStakeAmount * userRunningNode[msg.sender] * accRewardPerShare) /
            (ACCUMULATED_MULTIPLIER);
        if (totalPending > 0) {
            safeRewardTransfer(msg.sender, totalPending);
        }
        emit NodeStakingRewardsHarvested(msg.sender, totalPending);
        return totalPending;
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _amount amount to withdraw
     * @param _harvestReward whether the user want to claim the rewards or not
     */
    function _withdraw(uint256 _amount, bool _harvestReward) internal {
        NodeStakingUserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "NodeStakingPool: invalid amount");
        require(isInWithdrawTime(user.stakeTime), "NodeStakingPool: not in withdraw time");

        if (_harvestReward || user.amount == _amount) {
            claimReward();
        } else {
            updatePool();
            uint256 pending = ((requireStakeAmount * userRunningNode[msg.sender] * accRewardPerShare) /
                ACCUMULATED_MULTIPLIER) - user.rewardDebt;
            if (pending > 0) {
                user.pendingReward = user.pendingReward + pending;
            }
        }
        user.amount -= _amount;
        user.rewardDebt =
            (requireStakeAmount * userRunningNode[msg.sender] * accRewardPerShare) /
            ACCUMULATED_MULTIPLIER;
        stakeTokenSupply = stakeTokenSupply - _amount;
    }

    function isInWithdrawTime(uint256 _startTime) public view returns (bool) {
        uint256 duration = block.number - _startTime;
        // tmp is the times that done lockupDuration
        uint256 tmp = duration / (lockupDuration + withdrawPeriod);
        uint256 currentTime = duration - tmp * (lockupDuration + withdrawPeriod);

        return currentTime >= lockupDuration;
    }

    /**
     * @notice Safe reward transfer function, just in case if reward distributor dose not have enough reward tokens.
     * @param _to address of the receiver
     * @param _amount amount of the reward token
     */
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 bal = rewardToken.balanceOf(rewardDistributor);

        require(_amount <= bal, "NodeStakingPool: not enough reward token");

        rewardToken.safeTransferFrom(rewardDistributor, _to, _amount);
    }

    function rewardInTimeForUser(
        uint256 _totalSupply,
        uint256 _userBalance,
        uint256 _duration
    ) public view returns (uint256) {
        return (_userBalance * _duration * rewardPerBlock) / _totalSupply;
    }

    // function claimBoostReward(address _userAddress) public returns (uint256) {
    //     NodeStakingUserInfo memory user = userInfo[_userAddress];
    //     if (block.number < user.boostRewardAppliciableAt) return 0;

    //     rewardToken.safeTransferFrom(rewardDistributor, _to, user.boostReward);
    //     emit NodeStakingClaimBoostReward(_userAddress, user.boostReward);
    //     return user.boostReward;
    // }

    // function _boostReward(address _userAddress) private returns (uint256) {
    //     NodeStakingUserInfo memory user = userInfo[_userAddress];
    //     if (block.number < user.boostRewardAppliciableAt) return 0;

    //     rewardToken.safeTransferFrom(rewardDistributor, _to, user.boostReward);
    //     emit NodeStakingClaimBoostReward(_userAddress, user.boostReward);
    //     return user.boostReward;
    // }
}
