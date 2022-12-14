// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./NodeStaking.sol";
import "./interfaces/IPool.sol";
import "./proxy/OptimizedTransparentUpgradeableProxy.sol";

contract NodeStakingPoolFactory is Initializable, OwnableUpgradeable, PausableUpgradeable {
    // Array of created Pools Address
    address[] public allPools;
    // Mapping from User token. From tokens to array of created Pools for token
    mapping(address => mapping(address => address[])) public getPools;
    // address of implementation contract
    address public nodeStakingImplementation;

    event NodeStakingPoolCreated(
        address registedBy,
        string name,
        string symbol,
        address rewardToken,
        address stakeToken,
        address pool,
        uint256 poolId
    );
    event ImplementationChanged(address impl);

    function initialize() external initializer {
        __Ownable_init();
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
     * @notice Get the number of all created pools
     * @return Return number of created pools
     */
    function allPoolsLength() public view returns (uint256) {
        return allPools.length;
    }

    /**
     * @notice Get the created pools by token address
     * @dev User can retrieve their created pool by address of tokens
     * @param _creator Address of created pool user
     * @param _token Address of token want to query
     * @return Created NodeStakingPool Address
     */
    function getCreatedPoolsByToken(address _creator, address _token) public view returns (address[] memory) {
        return getPools[_creator][_token];
    }

    /**
     * @notice Retrieve number of pools created for specific token
     * @param _creator Address of created pool user
     * @param _token Address of token want to query
     * @return Return number of created pool
     */
    function getCreatedPoolsLengthByToken(address _creator, address _token) public view returns (uint256) {
        return getPools[_creator][_token].length;
    }

    function deployImplementation() external onlyOwner {
        nodeStakingImplementation = address(new NodeStakingPool());

        emit ImplementationChanged(nodeStakingImplementation);
    }

    function upgradeImplementation(address proxy, address newImpl) external onlyOwner {
        OptimizedTransparentUpgradeableProxy(payable(proxy)).upgradeTo(newImpl);
    }

    /**
     * @notice Register NodeStakingPool for tokens
     * @dev To register, you MUST have an ERC20 token
     */
    function registerPool(
        string memory _name,
        string memory _symbol,
        address _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _requireStakeAmount,
        uint256 _startBlock,
        address _stakeToken,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod,
        address _rewardDistributor
    ) external whenNotPaused onlyOwner returns (address pool) {
        require(nodeStakingImplementation != address(0), "NodeStakingPoolFactory: please deploy implemention before");
        require(_stakeToken != address(0), "NodeStakingPoolFactory: not allow zero address");
        require(_rewardToken != address(0), "NodeStakingPoolFactory: not allow zero address");

        bytes memory initData = abi.encodeWithSignature(
            "initialize(string,string,address,uint256,uint256,uint256,address,uint256,uint256,address)",
            _name,
            _symbol,
            IERC20(_rewardToken),
            _rewardPerBlock,
            _requireStakeAmount,
            _startBlock,
            IERC20(_stakeToken),
            _lockupDuration,
            _withdrawPeriod,
            _rewardDistributor
        );

        pool = address(
            new OptimizedTransparentUpgradeableProxy(
                nodeStakingImplementation,
                address(this), /* admin */
                initData
            )
        );

        getPools[msg.sender][_rewardToken].push(pool);
        allPools.push(pool);
        emit NodeStakingPoolCreated(msg.sender, _name, _symbol, _rewardToken, _stakeToken, pool, allPools.length - 1);
    }
}
