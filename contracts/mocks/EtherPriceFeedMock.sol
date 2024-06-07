// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract EtherPriceFeedMock is Ownable, AggregatorV3Interface {
    int256 private _answer;

    constructor(int256 answer) Ownable(_msgSender()) {
        _answer = answer;
    }

    function setAnswer(int256 answer) external {
        _answer = answer;
    }

    function getRoundData(
        uint80 roundId_
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = roundId_;
        answer = _answer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = _answer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "Ether price feed";
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}
