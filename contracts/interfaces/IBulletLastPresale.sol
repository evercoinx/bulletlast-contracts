// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Round {
        address saleToken;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 allocatedAmount;
        uint256 tokenDecimals;
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
        bool enableBuyWithEther;
        bool enableBuyWithUSDT;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 claimStart;
        uint256 claimEnd;
    }

    event RoundCreated(
        uint256 indexed roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 allocatedAmount,
        bool enableBuyWithEther,
        bool enableBuyWithUSDT
    );

    event RoundUpdated(bytes32 indexed operation, uint256 prevValue, uint256 newValue, uint256 timestamp);

    event TokensBought(
        address indexed user,
        uint256 indexed roundId,
        address indexed purchaseToken,
        uint256 tokensBought,
        uint256 amountPaid,
        uint256 timestamp
    );

    event TokensClaimed(address indexed user, uint256 indexed roundId, uint256 amount, uint256 timestamp);

    event RoundTokenAddressUpdated(address indexed prevValue, address indexed newValue, uint256 timestamp);

    event RoundPaused(uint256 indexed roundId, uint256 timestamp);

    event RoundUnpaused(uint256 indexed roundId, uint256 timestamp);

    error InvalidRoundId(uint256 roundId, uint256 currentRoundId);

    error ZeroPriceFeed();

    error ZeroUSDT();

    error ZeroPrice();

    error ZeroTokensToSell();

    error ZeroTokenDecimals();

    error ZeroStartAndEndTime();

    error ZeroSaleToken();

    error ZeroClaimAmount();

    error InvalidTimePeriod(uint256 currentTime, uint256 roundStartTime, uint256 roundEndTime);

    error InvalidBuyPeriod(uint256 currentTime, uint256 roundStartTime, uint256 roundEndTime);

    error InvalidSaleAmount(uint256 amount, uint256 roundAllocatedAmount);

    error InvalidVestingStartTime(uint256 vestingStartTime, uint256 roundEndTime);

    error SaleInPast(uint256 currentTime, uint256 startTime);

    error SaleAlreadyStarted(uint256 currentTime, uint256 roundStartTime);

    error InvalidSaleEndTime(uint256 endTime, uint256 roundStartTime);

    error SaleAlreadyEnded(uint256 currentTime, uint256 roundEndTime);

    error RoundAlreadyPaused(uint256 roundId);

    error RoundNotPaused(uint256 roundId);

    error BuyWithEtherForbidden(uint256 roundId);

    error BuyWithUSDTForbidden(uint256 roundId);

    error InsufficientEtherAmount(uint256 value, uint256 etherAmount);

    error InsufficientUSDTAllowance(uint256 allowance, uint256 usdPrice);

    error InsufficientCurrentBalance(uint256 amount, uint256 currentBalance);

    function createRound(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 allocatedAmount,
        uint256 tokenDecimals,
        uint256 vestingStartTime,
        uint256 vestingCliff,
        uint256 vestingPeriod,
        bool enableBuyWithEther,
        bool enableBuyWithUSDT
    ) external;

    function setSalePeriod(uint256 roundId, uint256 startTime, uint256 endTime) external;

    function setVestingStartTime(uint256 roundId, uint256 vestingStartTime) external;

    function setSaleToken(uint256 roundId, address saleToken) external;

    function setPrice(uint256 roundId, uint256 price) external;

    function setEnableBuyWithEther(uint256 roundId, bool enableBuyWithEther) external;

    function setEnableBuyWithUSDT(uint256 roundId, bool enableBuyWithUSDT) external;

    function pauseRound(uint256 roundId) external;

    function unpauseRound(uint256 roundId) external;

    function buyWithEther(uint256 roundId, uint256 amount) external payable returns (bool);

    function buyWithUSDT(uint256 roundId, uint256 amount) external returns (bool);

    // function claimMultiple(address[] calldata users, uint256 roundId) external returns (bool);

    function claim(address user, uint256 roundId) external returns (bool);

    function claimableAmount(address user, uint256 roundId) external view returns (uint256);

    function getLatestPrice() external view returns (uint256);
}
