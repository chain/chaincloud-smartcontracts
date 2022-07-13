// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;

contract MockOracle {
    uint256 public price;
    uint8 public decimals;

    function setPrice(uint256 _newPrice) external {
        price = _newPrice;
    }

    function setDecimals(uint8 _decimals) external {
        decimals = _decimals;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, price, 0, 0, 0);
    }
}
