// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Payment is Initializable, OwnableUpgradeable, PausableUpgradeable {
    enum PaymentType {
        PROVIDER_NODE_FEE_MONTHLY,
        PREMIUM_FEE_MONTHLY,
        ENTERPRISE_FEE_MONTHLY
    }

    address public treasury;
    address public XCNToken;
    address public usdtEthPriceFeed;
    address public usdtXcnPriceFeed;
    // type + token => amount
    mapping(PaymentType => uint256) public paymentAmountInUSDT;
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
    event SetPaymentAmount(PaymentType paymentType, uint256 amount);
    event SetDiscount(PaymentType paymentType, address token, uint256 discount);
    event ChangeTreasury(address treasury);
    event SetOracle(address usdtEthPriceFeed, address usdtXcnPriceFeed);

    function initialize(
        address _treasury,
        address _XCN,
        address _usdtEthPriceFeed,
        address _usdtXcnPriceFeed
    ) external initializer {
        __Ownable_init();
        treasury = _treasury;
        XCNToken = _XCN;
        usdtEthPriceFeed = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;
        usdtXcnPriceFeed = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;
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

    function setOracle(address _usdtEthPriceFeed, address _usdtXcnPriceFeed) external onlyOwner {
        usdtEthPriceFeed = _usdtEthPriceFeed;
        usdtXcnPriceFeed = _usdtXcnPriceFeed;

        emit SetOracle(_usdtEthPriceFeed, _usdtXcnPriceFeed);
    }

    function setPaymentAmount(PaymentType _type, uint256 _amount) external onlyOwner {
        paymentAmountInUSDT[_type] = _amount;
        emit SetPaymentAmount(_type, _amount);
    }

    function setDiscount(
        PaymentType _type,
        address _token,
        uint256 _discount
    ) external onlyOwner {
        discount[_type][_token] = _discount;
        emit SetDiscount(_type, _token, _discount);
    }

    function getPaymentAmount(PaymentType _type) external returns (uint256) {
        return paymentAmountInUSDT[_type];
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
            uint256 usdAmount = paymentAmountInUSDT[_type] -
                (paymentAmountInUSDT[_type] * discount[_type][address(0)]) /
                HUNDRED_PERCENT;
            uint256 requireETHAmount = getTokenAmountFromUSD(address(0), usdAmount);

            require(msg.value >= requireETHAmount, "Payment: not valid pay amount");

            // cashback exceeds amount to sender
            uint256 exceedETH = msg.value - requireETHAmount;
            if (exceedETH > 0) {
                payable(msg.sender).transfer(exceedETH);
            }
            emit Payment(msg.sender, _token, requireETHAmount, discount[_type][address(0)], _type, _paymentId);
        } else {
            uint256 usdAmount = paymentAmountInUSDT[_type] -
                (paymentAmountInUSDT[_type] * discount[_type][_token]) /
                HUNDRED_PERCENT;
            uint256 requireTokenAmount = getTokenAmountFromUSD(address(0), usdAmount);

            IERC20(_token).transferFrom(msg.sender, treasury, requireTokenAmount);
            emit Payment(msg.sender, _token, requireTokenAmount, discount[_type][_token], _type, _paymentId);
        }
    }

    function changeTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit ChangeTreasury(_treasury);
    }

    function getTokenAmountFromUSD(address _token, uint256 _usdAmount) public view returns (uint256) {
        (uint256 price, uint8 decimals) = getLatestPrice(_token);
        return (_usdAmount * price) / decimals;
    }

    function getLatestPrice(address _token)
        public
        view
        returns (
            uint256,
            uint8 /* decimals */
        )
    {
        address priceFeed;

        if (_token == address(0)) {
            priceFeed = usdtEthPriceFeed;
        } else if (_token == XCNToken) {
            priceFeed = usdtXcnPriceFeed;
        } else {
            revert("Payment: invalid token");
        }

        (, int256 price, , , ) = AggregatorV3Interface(priceFeed).latestRoundData();
        uint8 decimals = AggregatorV3Interface(priceFeed).decimals();
        return (uint256(price), decimals);
    }
}
