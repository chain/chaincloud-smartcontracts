// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Payment is Initializable, OwnableUpgradeable, PausableUpgradeable {
    enum PayType {
        PROVIDER_NODE_FEE_MONTHLY,
        PREMIUM_FEE_MONTHLY,
        ENTERPRISE_FEE_MONTHLY
    }

    address public treasury;
    // type + token => amount
    mapping(PayType => mapping(address => uint256)) public payAmount;

    event Pay(address payer, address token, uint256 amount, PayType payType);
    event SetPayAmount(PayType payType, address token, uint256 amount);
    event ChangeTreasury(address treasury);

    function initialize(address _treasury) external initializer {
        __Ownable_init();
        treasury = _treasury;
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

    function setPayAmount(
        PayType _type,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        payAmount[_type][_token] = _amount;
        emit SetPayAmount(_type, _token, _amount);
    }

    function pay(PayType _type, address _token) external {
        IERC20(_token).transferFrom(msg.sender, treasury, payAmount[_type][_token]);
        emit Pay(msg.sender, _token, payAmount[_type][_token], _type);
    }

    function changeTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit ChangeTreasury(_treasury);
    }
}
