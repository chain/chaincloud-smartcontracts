//SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract NodeStakingPool is Initializable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeCastUpgradeable for uint256;

    bytes32 public constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 private constant ACCUMULATED_MULTIPLIER = 1e12;

    // Info of each user + id.
    struct NodeStakingUserInfo {
        uint256 stakeTime; // stake block
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 pendingReward; // Reward but not harvest
        uint256 lastClaimBlock;

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

    struct PendingReward {
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
    // Info of each user that stakes LP tokens.
    mapping(address => mapping(uint256 => NodeStakingUserInfo)) public userInfo;
    // The block number when rewards mining starts.
    uint256 public startBlockNumber;
    // withdraw period: in withdrawPeriod, user can unstake
    uint256 public withdrawPeriod;
    // lockup duration: in lockupDuration, user cannot unstake
    uint256 public lockupDuration;
    // the weight of provider to earn reward
    mapping(address => uint256) public userRunningNode;
    mapping(address => uint256) public userNodeCount;
    mapping(address => uint256) public totalUserStaked;
    // pending reward
    mapping(address => mapping(uint256 => PendingReward)) public pendingReward;

    event NodeStakingDeposit(address user, uint256 amount, uint256 userNodeId, uint256 backendNodeId);
    event NodeStakingEnableAddress(address user, uint256 userNodeId);
    event NodeStakingDisableAddress(address user, uint256 userNodeId);
    event NodeStakingWithdraw(address user, uint256 amount, uint256 userNodeId);
    event NodeStakingRewardsHarvested(address user, uint256 amount, uint256 userNodeId);
    event SetRequireStakeAmount(uint256 amount);
    event SetRewardDistributor(address rewardDistributor);
    event SetRewardPerBlock(uint256 rewardPerBlock);
    event SetPoolInfor(
        uint256 rewardPerBlock,
        uint256 lockupDuration,
        uint256 withdrawPeriod,
        address rewardDistributor
    );

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
        uint256 _requireStakeAmount,
        uint256 _startBlock,
        IERC20 _stakeToken,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod,
        address _rewardDistributor
    ) external initializer {
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _setupRole(ADMIN_ROLE, tx.origin);
        _setupRole(PROPOSAL_ROLE, tx.origin);
        require(address(_rewardToken) != address(0), "NodeStakingPool: invalid reward token address");
        require(_rewardDistributor != address(0), "NodeStakingPool: invalid reward distributor address");
        require(_lockupDuration > 0, "NodeStakingPool: lockupDuration must be gt 0");
        require(_withdrawPeriod > 0, "NodeStakingPool: withdrawPeriod must be gt 0");
        require(requireStakeAmount > 0, "NodeStakingPool: requireStakeAmount must be gt 0");

        name = _name;
        symbol = _symbol;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        requireStakeAmount = _requireStakeAmount;
        startBlockNumber = _startBlock;
        lockupDuration = _lockupDuration;
        withdrawPeriod = _withdrawPeriod;
        rewardDistributor = _rewardDistributor;

        lastRewardBlock = block.number > startBlockNumber ? block.number : startBlockNumber;
        stakeToken = _stakeToken;
        _updatePool();
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyRole(PROPOSAL_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyRole(PROPOSAL_ROLE) {
        _unpause();
    }

    /**
     * @notice Set require stake amount
     * @param _requireStakeAmount amount want to set
     */
    function setRequireStakeAmount(uint256 _requireStakeAmount) external onlyRole(PROPOSAL_ROLE) {
        require(requireStakeAmount > 0, "NodeStakingPool: requireStakeAmount must be gt 0");

        requireStakeAmount = _requireStakeAmount;
        emit SetRequireStakeAmount(_requireStakeAmount);
    }

    /**
     * @notice Set the reward distributor. Can only be called by the owner.
     * @param _rewardDistributor the reward distributor
     */
    function setRewardDistributor(address _rewardDistributor) external onlyRole(PROPOSAL_ROLE) {
        require(_rewardDistributor != address(0), "NodeStakingPool: invalid reward distributor");
        rewardDistributor = _rewardDistributor;
        emit SetRewardDistributor(_rewardDistributor);
    }

    function setPoolInfor(
        uint256 _rewardPerBlock,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod,
        address _rewardDistributor
    ) external onlyRole(PROPOSAL_ROLE) {
        require(_lockupDuration > 0, "NodeStakingPool: lockupDuration must be gt 0");
        require(_withdrawPeriod > 0, "NodeStakingPool: withdrawPeriod must be gt 0");
        require(_rewardDistributor != address(0), "NodeStakingPool: invalid reward distributor address");

        _updatePool();

        rewardPerBlock = _rewardPerBlock;
        lockupDuration = _lockupDuration;
        withdrawPeriod = _withdrawPeriod;
        rewardDistributor = _rewardDistributor;

        emit SetPoolInfor(_rewardPerBlock, _lockupDuration, _withdrawPeriod, _rewardDistributor);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyRole(PROPOSAL_ROLE) {
        _updatePool();
        rewardPerBlock = _rewardPerBlock;

        emit SetRewardPerBlock(_rewardPerBlock);
    }

    /**
     * @notice Return time multiplier over the given _from to _to block.
     * @param _from the number of starting block
     * @param _to the number of ending block
     */
    function timeMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to - _from;
    }

    function getUserNodeInfo(address _user, uint256 _nodeId) external view returns (NodeStakingUserInfo memory) {
        return userInfo[_user][_nodeId];
    }

    function getPendingReward(address _user, uint256 _nodeId) external view returns (PendingReward memory) {
        return pendingReward[_user][_nodeId];
    }

    /**
     * @notice View function to see pending rewards on frontend.
     * @param _user the address of the user
     */
    function totalReward(address _user, uint256 _nodeId) public view returns (uint256) {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        if (user.stakeTime == 0) return user.pendingReward;

        // reward debt = accRewardPerShare before
        uint256 multiplier = timeMultiplier(lastRewardBlock, block.number);
        uint256 poolReward = multiplier * rewardPerBlock;
        uint256 _accRewardPerShare = accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / totalRunningNode);
        return user.pendingReward + ((_accRewardPerShare / ACCUMULATED_MULTIPLIER) - user.rewardDebt);
    }

    /**
     * @notice Update reward variables of the given pool to be up-to-date.
     */
    function _updatePool() private {
        if (block.number <= lastRewardBlock) {
            return;
        }
        if (totalRunningNode == 0) {
            lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = timeMultiplier(lastRewardBlock, block.number);
        uint256 poolReward = multiplier * rewardPerBlock;
        accRewardPerShare = (accRewardPerShare + ((poolReward * ACCUMULATED_MULTIPLIER) / totalRunningNode));
        lastRewardBlock = block.number;
    }

    /**
     * @notice Deposit LP tokens to the farm for reward allocation.
     */
    function deposit(uint256 _backendNodeId) external nonReentrant whenNotPaused {
        uint256 _amount = requireStakeAmount;

        uint256 index = userNodeCount[msg.sender]++;
        NodeStakingUserInfo storage user = userInfo[msg.sender][index];

        user.amount = _amount;
        stakeTokenSupply = stakeTokenSupply + _amount;
        totalUserStaked[msg.sender] += _amount;
        stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit NodeStakingDeposit(msg.sender, _amount, index, _backendNodeId);
    }

    function enableAddress(address _user, uint256 _nodeId) external onlyRole(ADMIN_ROLE) {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        require(user.amount != 0, "NodeStakingPool: invalid node id");
        require(user.stakeTime == 0, "NodeStakingPool: node already enabled");
        _updatePool();

        user.stakeTime = block.number;
        user.lastClaimBlock = block.number;
        user.rewardDebt = accRewardPerShare / ACCUMULATED_MULTIPLIER;
        userRunningNode[_user] = userRunningNode[_user] + 1;
        totalRunningNode = totalRunningNode + 1;

        emit NodeStakingEnableAddress(_user, _nodeId);
    }

    function disableAddress(address _user, uint256 _nodeId) external onlyRole(ADMIN_ROLE) {
        NodeStakingUserInfo storage user = userInfo[_user][_nodeId];

        require(user.stakeTime > 0, "NodeStakingPool: node already disabled");
        _updatePool();

        uint256 pending = ((accRewardPerShare) / ACCUMULATED_MULTIPLIER) - user.rewardDebt;

        user.pendingReward = user.pendingReward + pending;
        user.stakeTime = 0;
        user.rewardDebt = (accRewardPerShare) / ACCUMULATED_MULTIPLIER;
        totalRunningNode = totalRunningNode - 1;
        userRunningNode[_user] = userRunningNode[_user] - 1;

        emit NodeStakingDisableAddress(_user, _nodeId);
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _nodeId nodeId to withdraw
     */
    function withdraw(uint256 _nodeId) external nonReentrant whenNotPaused {
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        if (user.stakeTime > 0) {
            require(isInWithdrawTime(user.stakeTime), "NodeStakingPool: not in withdraw time");
        }
        require(user.amount > 0, "NodeStakingPool: have not any token to withdraw");

        uint256 amount = user.amount;

        _withdraw(_nodeId);

        stakeToken.safeTransfer(address(msg.sender), amount);
        emit NodeStakingWithdraw(msg.sender, amount, _nodeId);
    }

    /**
     * @notice Harvest proceeds msg.sender
     */
    function claimReward(uint256 _nodeId) public nonReentrant whenNotPaused returns (uint256) {
        return _claimReward(_nodeId);
    }

    /**
     * @notice Withdraw LP tokens from
     * @param _nodeId nodeId to withdraw
     */
    function _withdraw(uint256 _nodeId) private {
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        uint256 _amount = user.amount;
        bool isDisabledBefore = user.stakeTime == 0;

        _claimReward(_nodeId);
        user.stakeTime = 0;
        user.amount = 0;
        totalUserStaked[msg.sender] -= _amount;

        if (!isDisabledBefore) {
            totalRunningNode -= 1;
            userRunningNode[msg.sender] -= 1;
        }
        stakeTokenSupply = stakeTokenSupply - _amount;
    }

    function isInWithdrawTime(uint256 _startTime) public view returns (bool) {
        uint256 duration = block.number - _startTime;
        uint256 multiplier = duration / (lockupDuration + withdrawPeriod);
        uint256 currentTime = duration - multiplier * (lockupDuration + withdrawPeriod);

        return currentTime >= lockupDuration;
    }

    function getNextStartLockingTime(uint256 _startTime) public view returns (uint256) {
        if (_startTime == 0) return block.number;
        uint256 duration = block.number - _startTime;
        // multiplier is the times that done lockupDuration
        uint256 multiplier = duration / (lockupDuration + withdrawPeriod);

        return _startTime + (multiplier + 1) * (lockupDuration + withdrawPeriod);
    }

    function getLastEndLockingTime(uint256 _startTime) public view returns (uint256) {
        if (_startTime == 0) return block.number;
        uint256 duration = block.number - _startTime;
        // multiplier is the times that done lockupDuration
        uint256 multiplier = duration / (lockupDuration + withdrawPeriod);

        uint256 bias = duration - multiplier * (lockupDuration + withdrawPeriod);
        if (bias < lockupDuration) return _startTime + multiplier * (lockupDuration + withdrawPeriod) - withdrawPeriod;

        return _startTime + multiplier * (lockupDuration + withdrawPeriod) + lockupDuration;
    }

    /**
     * @notice Safe reward transfer function, just in case if reward distributor dose not have enough reward tokens.
     * @param _to address of the receiver
     * @param _amount amount of the reward token
     */
    function safeRewardTransfer(address _to, uint256 _amount) private {
        uint256 bal = rewardToken.balanceOf(rewardDistributor);

        require(_amount <= bal, "NodeStakingPool: not enough reward token");

        rewardToken.safeTransferFrom(rewardDistributor, _to, _amount);
    }

    function getAvailableReward(address _user, uint256 _nodeId) external view returns (uint256) {
        NodeStakingUserInfo memory user = userInfo[_user][_nodeId];
        uint256 totalPending = totalReward(_user, _nodeId);
        return totalPending - _getPendingReward(_user, _nodeId, block.number - user.lastClaimBlock, totalPending);
    }

    function _claimReward(uint256 _nodeId) private returns (uint256) {
        _updatePool();
        NodeStakingUserInfo storage user = userInfo[msg.sender][_nodeId];
        uint256 totalPending = totalReward(msg.sender, _nodeId);
        user.pendingReward = 0;
        user.rewardDebt = (accRewardPerShare) / (ACCUMULATED_MULTIPLIER);

        uint256 tempPendingReward = _getPendingReward(
            msg.sender,
            _nodeId,
            block.number - user.lastClaimBlock,
            totalPending
        );
        uint256 totalAmount = 0;

        // claim pending reward in withdraw time
        PendingReward storage record = pendingReward[msg.sender][_nodeId];
        if ((record.applicableAt < block.number && record.reward > 0) || (user.stakeTime == 0)) {
            totalAmount += record.reward;
            record.reward = 0;
        }

        if (tempPendingReward > 0) {
            // next locking time
            record.applicableAt = getLastEndLockingTime(user.stakeTime) + lockupDuration + withdrawPeriod;
            record.reward += tempPendingReward;

            // if (record.applicableAt <= block.number) {
            //     safeRewardTransfer(msg.sender, record.reward);
            //     record.reward = 0;
            // }
        }

        totalAmount += totalPending - tempPendingReward;
        safeRewardTransfer(msg.sender, totalAmount);

        user.lastClaimBlock = block.number;

        emit NodeStakingRewardsHarvested(msg.sender, totalPending, _nodeId);
        return totalPending;
    }

    // lượng reward trong lockup period
    function _getPendingReward(
        address _user,
        uint256 _nodeId,
        uint256 _totalStakeTime,
        uint256 _totalReward
    ) private view returns (uint256) {
        NodeStakingUserInfo memory user = userInfo[_user][_nodeId];
        if (user.stakeTime == 0) return 0;

        // get time in lockup period and last withdraw period
        uint256 lastLockingTime = getLastEndLockingTime(user.stakeTime);
        uint256 lastBlock = user.lastClaimBlock > lastLockingTime ? user.lastClaimBlock : lastLockingTime;
        uint256 duration = block.number - lastBlock;
        uint256 reward = (duration * _totalReward) / _totalStakeTime;

        return reward;
    }
}
