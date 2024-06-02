// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    event PresaleCreated(
        uint256 indexed _id,
        uint256 _totalTokens,
        uint256 _startTime,
        uint256 _endTime,
        uint256 enableBuyWithEth,
        uint256 enableBuyWithUsdt
    );

    event PresaleUpdated(bytes32 indexed key, uint256 prevValue, uint256 newValue, uint256 timestamp);

    event TokensBought(
        address indexed user,
        uint256 indexed id,
        address indexed purchaseToken,
        uint256 tokensBought,
        uint256 amountPaid,
        uint256 timestamp
    );

    event TokensClaimed(address indexed user, uint256 indexed id, uint256 amount, uint256 timestamp);

    event PresaleTokenAddressUpdated(address indexed prevValue, address indexed newValue, uint256 timestamp);

    event PresalePaused(uint256 indexed id, uint256 timestamp);
    event PresaleUnpaused(uint256 indexed id, uint256 timestamp);
}
