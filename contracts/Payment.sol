// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IERC20Decimals {
    function decimals() external view returns (uint8);
}

contract Payment is Initializable, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    enum PaymentType {
        PROVIDER_NODE_FEE_MONTHLY,
        PREMIUM_FEE_MONTHLY,
        ENTERPRISE_FEE_MONTHLY
    }

    address public treasury;
    address public XCNToken;
    address public USDTToken;
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
    event SetTokenAddress(address USDT, address XCN);

    function initialize(
        address _treasury,
        address _XCN,
        address _USDT,
        address _usdtEthPriceFeed,
        address _usdtXcnPriceFeed
    ) external initializer {
        __Ownable_init();
        require(_treasury != address(0), "Payment: not allow zero address");
        require(_XCN != address(0), "Payment: not allow zero address");
        require(_USDT != address(0), "Payment: not allow zero address");
        require(_usdtEthPriceFeed != address(0), "Payment: not allow zero address");
        require(_usdtXcnPriceFeed != address(0), "Payment: not allow zero address");

        treasury = _treasury;
        XCNToken = _XCN;
        USDTToken = _USDT;
        usdtEthPriceFeed = _usdtEthPriceFeed;
        usdtXcnPriceFeed = _usdtXcnPriceFeed;
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
        require(_usdtEthPriceFeed != address(0), "Payment: not allow zero address");
        require(_usdtXcnPriceFeed != address(0), "Payment: not allow zero address");

        usdtEthPriceFeed = _usdtEthPriceFeed;
        usdtXcnPriceFeed = _usdtXcnPriceFeed;

        emit SetOracle(_usdtEthPriceFeed, _usdtXcnPriceFeed);
    }

    function setTokenAddress(address _USDT, address _XCN) external onlyOwner {
        require(_XCN != address(0), "Payment: not allow zero address");
        require(_USDT != address(0), "Payment: not allow zero address");

        USDTToken = _USDT;
        XCNToken = _XCN;

        emit SetTokenAddress(_USDT, _XCN);
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

    function changeTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Payment: not allow zero address");

        treasury = _treasury;
        emit ChangeTreasury(_treasury);
    }

    function getTokenAmountFromUSDT(address _token, uint256 _usdtAmount) public view returns (uint256) {
        (uint256 price, uint8 decimals) = getLatestPrice(_token);
        uint8 usdtDecimals = IERC20Decimals(USDTToken).decimals();

        if (_token == address(0)) return (_usdtAmount * 10**18 * 10**decimals) / (price * 10**usdtDecimals);

        uint8 tokenDecimals = IERC20Decimals(_token).decimals();
        return (_usdtAmount * 10**tokenDecimals * 10**decimals) / (price * 10**usdtDecimals);
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
        } else if (_token == USDTToken) {
            return (1, 0);
        } else {
            revert("Payment: invalid token");
        }

        (, int256 price, , , ) = AggregatorV3Interface(priceFeed).latestRoundData();
        uint8 decimals = AggregatorV3Interface(priceFeed).decimals();
        return (uint256(price), decimals);
    }

    function getDiscountAmount(PaymentType _type, address _token) external view returns (uint256) {
        return discount[_type][_token];
    }

    function pay(
        PaymentType _type,
        address _token,
        uint256 _paymentId
    ) external payable whenNotPaused {
        uint256 usdtAmount = paymentAmountInUSDT[_type] -
            (paymentAmountInUSDT[_type] * discount[_type][_token]) /
            HUNDRED_PERCENT;

        uint256 requireAmount = getTokenAmountFromUSDT(_token, usdtAmount);
        emit Payment(msg.sender, _token, requireAmount, discount[_type][_token], _type, _paymentId);

        if (_token == address(0)) {
            require(msg.value >= requireAmount, "Payment: not valid pay amount");

            // cashback exceeds amount to sender
            uint256 exceedETH = msg.value - requireAmount;
            if (exceedETH > 0) {
                payable(msg.sender).transfer(exceedETH);
            }

            return;
        }

        IERC20(_token).safeTransferFrom(msg.sender, treasury, requireAmount);
    }
}
