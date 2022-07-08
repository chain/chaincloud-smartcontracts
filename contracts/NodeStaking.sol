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

    // Info of each user + id.
    struct NodeStakingUserInfo {
        uint256 stakeTime; // next reward block
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 pendingReward; // Reward but not harvest
        // TODO: if switch from 1 to 0, transfer reward to user before set stakeTime to 0
        // bool status; // 0: inactive, 1: active

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
    uint256 public requireStakeAmount; // stake amount need for user to run node
    uint256 public nextRewardBlock; // the lastest time that reward stop calculate and user can be withdraw

    struct LockWithdrawReward {
        uint256 reward;
        uint256 applicableAt;
    }

    string public name;
    string public symbol;
    // The reward token!
    IERC20 public rewardToken;
    // Total rewards for each block.
    uint256 public rewardPerBlock;
    // The reward distribution address
    address public rewardDistributor;
    // Allow emergency withdraw feature
    bool public allowEmergencyWithdraw;
    // Info of each user that stakes LP tokens.
    mapping(address => mapping(uint256 => NodeStakingUserInfo)) public userInfo;
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
    mapping(address => uint256) public userNodeCount;
    // pending reward in withdraw period
    mapping(address => mapping(uint256 => LockWithdrawReward)) public pendingRewardInWithdrawPeriod;

    event NodeStakingDeposit(address user, uint256 amount, uint256 userNodeId);
    event NodeStakingEnableAddress(address user, uint256 userNodeId);
    event NodeStakingDisableAddress(address user, uint256 userNodeId);
    event NodeStakingWithdraw(address user, uint256 amount);
    event NodeStakingRewardsHarvested(address user, uint256 amount);
    event SetRequireStakeAmount(uint256 amount);
    event SetEndBlock(uint256 block);
    event SetRewardDistributor(address rewardDistributor);
    event SetRewardPerBlock(uint256 rewardPerBlock);
    event SetPoolInfor(uint256 rewardPerBlock, uint256 endBlock, uint256 lockupDuration, uint256 withdrawPeriod);

    /**
     * @notice Initialize the contract, get called in the first time deploy
     * @param _rewardToken the reward token address
     * @param _rewardPerBlock the number of reward tokens that got unlocked each block
     * @param _startBlock the block number when farming start
     */
    function initialize(
        string memory _name,
        string memory _symbol,
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        IERC20 _stakeToken,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod
    ) external initializer {
        __Ownable_init();
        transferOwnership(tx.origin);
        require(address(_rewardToken) != address(0), "NodeStakingPool: invalid reward token address");
        require(_startBlock < _endBlock, "NodeStakingPool: invalid start block or end block");
        require(_lockupDuration > 0, "NodeStakingPool: lockupDuration must be gt 0");
        require(_withdrawPeriod > 0, "NodeStakingPool: withdrawPeriod must be gt 0");

        name = _name;
        symbol = _symbol;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        startBlockNumber = _startBlock;
        endBlockNumber = _endBlock;
        lockupDuration = _lockupDuration;
        withdrawPeriod = _withdrawPeriod;

        lastRewardBlock = block.number > startBlockNumber ? block.number : startBlockNumber;
        stakeToken = _stakeToken;
        stakeTokenSupply = 0;
        totalRunningNode = 0;
        requireStakeAmount = 0;
        accRewardPerShare = 0;
        updatePool();
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
     * @notice Set require stake amount
     * @param _requireStakeAmount amount want to set
     */
    function setRequireStakeAmount(uint256 _requireStakeAmount) external onlyOwner {
        requireStakeAmount = _requireStakeAmount;
        emit SetRequireStakeAmount(_requireStakeAmount);
    }

    /**
     * @notice Set the reward distributor. Can only be called by the owner.
     * @param _rewardDistributor the reward distributor
     */
    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        require(_rewardDistributor != address(0), "NodeStakingPool: invalid reward distributor");
        rewardDistributor = _rewardDistributor;
        emit SetRewardDistributor(_rewardDistributor);
    }

    function setPoolInfor(
        uint256 _rewardPerBlock,
        uint256 _endBlock,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod
    ) external onlyOwner {
        require(_endBlock > block.number, "NodeStakingPool: end block must be gt block.number");
        require(_lockupDuration > 0, "NodeStakingPool: lockupDuration must be gt 0");
        require(_withdrawPeriod > 0, "NodeStakingPool: withdrawPeriod must be gt 0");

        updatePool();

        rewardPerBlock = _rewardPerBlock;
        endBlockNumber = _endBlock;
        lockupDuration = _lockupDuration;
        withdrawPeriod = _withdrawPeriod;

        emit SetPoolInfor(_rewardPerBlock, _endBlock, _lockupDuration, _withdrawPeriod);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external {
        updatePool();
        rewardPerBlock = _rewardPerBlock;

        emit SetRewardPerBlock(_rewardPerBlock);
    }

    /**
     * @notice Set the end block number. Can only be called by the owner.
     */
    function setEndBlock(uint256 _endBlockNumber) external onlyOwner {
        require(_endBlockNumber > block.number, "NodeStakingPool: invalid reward distributor");
        endBlockNumber = _endBlockNumber;
        emit SetEndBlock(_endBlockNumber);
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
        uint256 currBlockNumber = block.number;
        if (currBlockNumber > endBlockNumber) {
            currBlockNumber = endBlockNumber;
        }

        uint256 duration = currBlockNumber - startBlockNumber;

        // tmp is the times that done lockupDuration
        uint256 tmp = duration / (lockupDuration + withdrawPeriod);
        return startBlockNumber + tmp * lockupDuration + withdrawPeriod;
    }

    /**
     * @notice View function to see pending rewards on frontend.
     * @param _user the address of the user
     */
    function pendingReward(address _user, uint256 _nodeId) public view returns (uint256) {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        // TODO: reward debt = accRewardPerShare before
        uint256 _accRewardPerShare = accRewardPerShare;
        if (user.stakeTime > 0 && block.number > lastRewardBlock && totalRunningNode != 0) {
            uint256 multiplier = timeMultiplier(lastRewardBlock, block.number);
            uint256 poolReward = multiplier * rewardPerBlock;
            _accRewardPerShare = _accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / totalRunningNode);
        }
        return user.pendingReward + ((_accRewardPerShare / ACCUMULATED_MULTIPLIER) - user.rewardDebt);
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalRunningNode == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = timeMultiplier(lastRewardBlock, block.number);
        uint256 poolReward = multiplier * rewardPerBlock;
        // TODO: stakeTokenSupply or count*requireAmount
        accRewardPerShare = (accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / (totalRunningNode)));
        lastRewardBlock = block.number;
    }

    /**
     * @notice Deposit LP tokens to the farm for reward allocation.
     */
    function deposit() external {
        uint256 _amount = requireStakeAmount;

        uint256 index = userNodeCount[msg.sender]++;
        NodeStakingUserInfo storage user = userInfo[msg.sender][index];
        // if admin enable staking record, stakeTime will be update
        // user.stakeTime = block.number;
        user.amount = _amount;
        stakeTokenSupply = stakeTokenSupply + _amount;
        stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit NodeStakingDeposit(msg.sender, _amount, index);
    }

    // TODO: set pool
    function setPool() external {}

    function enableAddress(address _user, uint256 _nodeId) external onlyOwner {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        require(user.stakeTime == 0, "NodeStakingPool: node already enabled");
        updatePool();

        user.stakeTime = block.number;
        userRunningNode[_user] = userRunningNode[_user] + 1;
        totalRunningNode = totalRunningNode + 1;

        emit NodeStakingEnableAddress(msg.sender, _nodeId);
    }

    function disableAddress(address _user, uint256 _nodeId) external onlyOwner {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        require(user.stakeTime > 0, "NodeStakingPool: node already disabled");
        // require(isInWithdrawTime(user.stakeTime), "NodeStakingPool: not in withdraw time");
        updatePool();
        if (user.stakeTime > 0) {
            uint256 pending = ((accRewardPerShare) / ACCUMULATED_MULTIPLIER) - user.rewardDebt;

            if (pending > 0) {
                user.pendingReward = user.pendingReward + pending;
            }
        }
        user.stakeTime = 0;
        user.rewardDebt = (accRewardPerShare) / ACCUMULATED_MULTIPLIER;
        totalRunningNode = totalRunningNode - 1;
        userRunningNode[_user] = userRunningNode[_user] - 1;
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _nodeId nodeId to withdraw
     * @param _harvestReward whether the user want to claim the rewards or not
     */
    function withdraw(uint256 _nodeId, bool _harvestReward) external {
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        require(isInWithdrawTime(user.stakeTime), "NodeStakingPool: not in withdraw time");
        require(user.amount > 0, "NodeStakingPool: have not any token to withdraw");

        uint256 amount = user.amount;

        _withdraw(_nodeId, _harvestReward);

        stakeToken.safeTransfer(address(msg.sender), amount);
        emit NodeStakingWithdraw(msg.sender, amount);
    }

    /**
     * @notice Harvest proceeds msg.sender
     */
    function claimReward(uint256 _nodeId) public returns (uint256) {
        uint256 multiplier = timeMultiplier(lastRewardBlock, block.number);

        updatePool();
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        uint256 totalPending = pendingReward(msg.sender, _nodeId);

        user.pendingReward = 0;
        user.rewardDebt = (accRewardPerShare) / (ACCUMULATED_MULTIPLIER);

        uint256 lockReward = _getWithdrawPendingReward(_nodeId, multiplier, totalPending);
        if (totalPending > 0) {
            safeRewardTransfer(msg.sender, totalPending - lockReward);
        }

        // TODO: claim pending reward in withdraw time
        LockWithdrawReward storage record = pendingRewardInWithdrawPeriod[msg.sender][_nodeId];
        if (record.applicableAt > block.number) {
            safeRewardTransfer(msg.sender, record.reward);
            record.reward = 0;
        }

        if (lockReward > 0) {
            // TODO: next locking time
            record.applicableAt = getNextStartLockingTime(user.stakeTime);
            record.reward += lockReward;

            if (record.applicableAt <= block.number) {
                safeRewardTransfer(msg.sender, record.reward);
                record.reward = 0;
            }
        }
        emit NodeStakingRewardsHarvested(msg.sender, totalPending);
        return totalPending;
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _nodeId nodeId to withdraw
     * @param _harvestReward whether the user want to claim the rewards or not
     */
    function _withdraw(uint256 _nodeId, bool _harvestReward) private {
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        uint256 _amount = user.amount;
        // require(isInWithdrawTime(user.stakeTime), "NodeStakingPool: not in withdraw time");

        if (_harvestReward) {
            claimReward(_nodeId);
        } else {
            updatePool();
            // user have stake time = user deposited
            if (user.stakeTime > 0) {
                uint256 pending = ((accRewardPerShare) / ACCUMULATED_MULTIPLIER) - user.rewardDebt;
                if (pending > 0) {
                    user.pendingReward = user.pendingReward + pending;
                }
            }
        }
        user.amount = 0;
        user.stakeTime = 0;
        user.rewardDebt = (accRewardPerShare) / ACCUMULATED_MULTIPLIER;
        stakeTokenSupply = stakeTokenSupply - _amount;
    }

    function isInWithdrawTime(uint256 _startTime) public view returns (bool) {
        uint256 duration = block.number - _startTime;
        // tmp is the times that done lockupDuration
        uint256 tmp = duration / (lockupDuration + withdrawPeriod);
        uint256 currentTime = duration - tmp * (lockupDuration + withdrawPeriod);

        return currentTime >= lockupDuration;
    }

    function getNextStartLockingTime(uint256 _startTime) public view returns (uint256) {
        if (_startTime == 0) return block.number;
        uint256 duration = block.number - _startTime;
        // multiplier is the times that done lockupDuration
        uint256 multiplier = duration / (lockupDuration + withdrawPeriod);

        return (multiplier + 1) * (lockupDuration + withdrawPeriod);
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

    // TODO: lượng reward trong withdraw period
    function _getWithdrawPendingReward(
        uint256 _nodeId,
        uint256 _totalStakeTime,
        uint256 _totalReward
    ) private returns (uint256) {
        require(_totalStakeTime > 0, "NodeStakingPool: stake time must be greater than 0");

        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        require(user.stakeTime > 0, "NodeStakingPool: NodeStakingPool: node already disabled");
        // get time in withdraw period
        uint256 nextLockingTime = getNextStartLockingTime(user.stakeTime);
        uint256 duration = withdrawPeriod - (nextLockingTime - block.number);

        uint256 reward = (duration * _totalReward) / _totalStakeTime;

        return reward;
    }
}
