// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPool {
    function initialize(
        IERC20 _rewardToken,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _endBlock,
        IERC20 _stakeToken,
        uint256 _lockupDuration,
        uint256 _withdrawPeriod,
        uint256 _delayDuration
    ) external;
}
