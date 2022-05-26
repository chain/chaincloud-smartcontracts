// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Payment {
   constructor(address _treasury, address _token, uint256 _payAmount) {
       treasury = _treasury;
       payAmount = _payAmount;
       token = _token;
       owner = msg.sender;
   }

    address public treasury;
    address public token;
    address public owner;
    uint256 public payAmount;

    event Pay(address payer, uint256 amount);
    event ChangeOwner(address oldOwner, address newOwner);
    event UpdateContractInfo(address treasury, address token, uint256 payAmount);

    modifier onlyOwner {
        require(msg.sender == owner, "Not owner of contract");
        _;
    }
   
    function pay() external {
        IERC20(token).transferFrom(msg.sender, treasury, payAmount);
        emit Pay(msg.sender, payAmount);
    }

    function changeOwner(address _owner) external onlyOwner {
        emit ChangeOwner(owner, _owner);
        owner = _owner;
    }

    function updateContract(address _treasury, address _token, uint256 _payAmount) external onlyOwner {
        treasury = _treasury;
        payAmount = _payAmount;
        token = _token;
        emit UpdateContractInfo(_treasury, _token, _payAmount);
    }
}
