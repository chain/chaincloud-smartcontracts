// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Payment {
    constructor(address _treasury, address _token) {
        treasury = _treasury;
        token = _token;
        owner = msg.sender;
    }

    // pay type
    enum PayType {
        PROVIDER_NODE_FEE_MONTHLY,
        PREMIUM_FEE_MONTHLY,
        ENTERPRISE_FEE_MONTHLY
    }

    address public treasury;
    address public token;
    address public owner;
    mapping(PayType => uint256) public payAmount;

    event Pay(address payer, uint256 amount, PayType payType);
    event ChangeOwner(address oldOwner, address newOwner);
    event SetPayAmount(PayType payType, uint256 amount);
    event UpdateContractInfo(address treasury, address token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner of contract");
        _;
    }

    function setPayAmount(PayType _type, uint256 _amount) external onlyOwner {
        payAmount[_type] = _amount;
        emit SetPayAmount(_type, _amount);
    }

    function pay(PayType _type) external {
        IERC20(token).transferFrom(msg.sender, treasury, payAmount[_type]);
        emit Pay(msg.sender, payAmount[_type], _type);
    }

    function changeOwner(address _owner) external onlyOwner {
        emit ChangeOwner(owner, _owner);
        owner = _owner;
    }

    function updateContract(address _treasury, address _token) external onlyOwner {
        treasury = _treasury;
        token = _token;
        emit UpdateContractInfo(_treasury, _token);
    }
}
