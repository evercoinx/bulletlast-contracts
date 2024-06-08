// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract EtherPriceFeedMock is Ownable, AggregatorV3Interface {
    mapping(uint256 roundId => int256 answer) public roundAnswers;

    uint256 private _currentRoundId;

    constructor(int256[2][] memory roundAnswers_) Ownable(_msgSender()) {
        uint256 roundAnswerCount = roundAnswers_.length;
        uint256 roundId = 0;

        for (uint256 i = 0; i < roundAnswerCount; i++) {
            roundId = uint256(roundAnswers_[i][0]);
            roundAnswers[roundId] = roundAnswers_[i][1];
        }

        _currentRoundId = roundId;
    }

    function getRoundData(
        uint80 roundId_
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = roundId_;
        answer = roundAnswers[roundId];
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = uint80(_currentRoundId);
        answer = roundAnswers[roundId];
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
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
