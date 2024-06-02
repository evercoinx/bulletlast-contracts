// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Presale {
        address saleToken;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 tokensToSell;
        uint256 baseDecimals;
        uint256 inSale;
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
        uint256 enableBuyWithEther;
        uint256 enableBuyWithUSDT;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 claimStart;
        uint256 claimEnd;
    }

    event PresaleCreated(
        uint256 indexed id,
        uint256 totalTokens,
        uint256 startTime,
        uint256 endTime,
        uint256 enableBuyWithEther,
        uint256 enableBuyWithUSDT
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
