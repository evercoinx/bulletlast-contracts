// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Round {
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
        uint256 startTime;
        uint256 endTime;
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

    event RoundUpdated(bytes32 indexed operation, uint256 prevValue, uint256 newValue);

    event SaleTokenSet(address indexed saleToke);

    event SaleTokenWithEtherBought(
        address indexed user,
        uint256 indexed roundId,
        address indexed purchaseToken,
        uint256 purchaseTokenAmount,
        uint256 saleTokenAmount
    );

    event SaleTokenWithUSDTBought(
        address indexed user,
        uint256 indexed roundId,
        address indexed purchaseToken,
        uint256 purchaseTokenAmount,
        uint256 saleTokenAmount
    );

    event SaleTokenClaimed(address indexed user, uint256 indexed roundId, uint256 amount);

    event RoundPaused(uint256 indexed roundId);

    event RoundUnpaused(uint256 indexed roundId);

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

    error EtherTransferFailed(address to, uint256 amount);

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

    function setSaleToken(address saleToken) external;

    function setSalePeriod(uint256 roundId, uint256 startTime, uint256 endTime) external;

    function setVestingStartTime(uint256 roundId, uint256 vestingStartTime) external;

    function setPrice(uint256 roundId, uint256 price) external;

    function setEnableBuyWithEther(uint256 roundId, bool enableBuyWithEther) external;

    function setEnableBuyWithUSDT(uint256 roundId, bool enableBuyWithUSDT) external;

    function pauseRound(uint256 roundId) external;

    function unpauseRound(uint256 roundId) external;

    function buySaleTokenWithEther(uint256 roundId, uint256 amount) external payable;

    function buySaleTokenWithUSDT(uint256 roundId, uint256 amount) external;

    function claimSaleToken(address user, uint256 roundId) external;

    function claimableSaleTokenAmount(address user, uint256 roundId) external view returns (uint256);

    function getLatestEtherPrice() external view returns (uint256);
}
