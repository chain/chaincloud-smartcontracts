// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract Payment is Initializable, OwnableUpgradeable, PausableUpgradeable {
    enum PaymentType {
        PROVIDER_NODE_FEE_MONTHLY,
        PREMIUM_FEE_MONTHLY,
        ENTERPRISE_FEE_MONTHLY
    }

    address public treasury;
    // type + token => amount
    mapping(PaymentType => mapping(address => uint256)) public payAmount;
    mapping(PaymentType => mapping(address => uint256)) public discount; // unit 1e18
    uint256 public constant HUNDRED_PERCENT = 1e18;

    event Payment(
        address payer,
        address token,
        uint256 amount,
        uint256 discount,
        PaymentType paymentType,
        uint256 paymentId
    );
    event SetPayAmount(PaymentType paymentType, address token, uint256 amount);
    event SetDiscount(PaymentType paymentType, address token, uint256 discount);
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
        PaymentType _type,
        address _token,
        uint256 _amount
    ) external onlyOwner {
        payAmount[_type][_token] = _amount;
        emit SetPayAmount(_type, _token, _amount);
    }

    function setDiscount(
        PaymentType _type,
        address _token,
        uint256 _discount
    ) external onlyOwner {
        discount[_type][_token] = _discount;
        emit SetDiscount(_type, _token, _discount);
    }

    function getPayAmount(PaymentType _type, address _token) external returns (uint256) {
        return payAmount[_type][_token];
    }

    function getDiscountAmount(PaymentType _type, address _token) external returns (uint256) {
        return discount[_type][_token];
    }

    function pay(
        PaymentType _type,
        address _token,
        uint256 _paymentId
    ) external payable {
        if (_token == address(0)) {
            require(
                msg.value ==
                    payAmount[_type][address(0)] -
                        (payAmount[_type][address(0)] * discount[_type][address(0)]) /
                        HUNDRED_PERCENT,
                "Payment: not valid pay amount"
            );
        } else {
            IERC20(_token).transferFrom(
                msg.sender,
                treasury,
                payAmount[_type][_token] - (payAmount[_type][_token] * discount[_type][_token]) / HUNDRED_PERCENT
            );
        }

        emit Payment(msg.sender, _token, payAmount[_type][_token], discount[_type][_token], _type, _paymentId);
    }

    function changeTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit ChangeTreasury(_treasury);
    }
}
