// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Round {
        uint64 startTime;
        uint64 endTime;
        uint16 price;
    }

    struct Vesting {
        uint256 amount;
        uint64 startTime;
    }

    event TreasurySet(address indexed treasury);

    event ActiveRoundIdSet(uint256 activeRoundId);

    event AllocatedAmountSet(uint256 allocatedAmount);

    event RoundCreated(uint8 id, uint64 startTime, uint64 endTime, uint16 price);

    event RoundUpdated(uint8 id, uint64 startTime, uint64 endTime, uint16 price);

    event BoughtWithEther(address indexed user, uint256 indexed roundId, uint256 amount, uint256 etherAmount);

    event BoughtWithUSDT(address indexed user, uint256 indexed roundId, uint256 amount, uint256 usdtAmount);

    event Claimed(address indexed user, uint256 amount);

    error ZeroSaleToken();

    error ZeroPriceFeed();

    error ZeroUSDTToken();

    error ZeroTreasury();

    error ZeroVestingDuration();

    error ZeroPrice();

    error ZeroActiveRoundId();

    error ZeroRoundId();

    error RoundNotFound();

    error InvalidActiveRoundId(uint256 activeRoundId);

    error InvalidTimePeriod(uint256 startTime, uint256 endTime);

    error RoundAlreadyExists(uint256 roundId);

    error TooLowEtherBuyAmount(uint256 etherAmount, uint256 amount);

    error TooHighEtherBuyAmount(uint256 etherAmount, uint256 amount);

    error InsufficientEtherAmount(uint256 expectedAmount, uint256 actualAmount);

    error TooLowUSDTBuyAmount(uint256 usdtAmount, uint256 amount);

    error TooHighUSDTBuyAmount(uint256 usdtAmount, uint256 amount);

    error InvalidBuyPeriod(uint256 currentTime, uint256 startTime, uint256 endTime);

    error InsufficientAllocatedAmount(uint256 amount, uint256 allocatedAmount);

    error ZeroClaimableAmount(address user);

    error EtherTransferFailed(address to, uint256 amount);

    function pause() external;

    function unpause() external;

    function setTreasury(address treasury) external;

    function setActiveRoundId(uint8 activeRoundId) external;

    function createRound(uint8 id, uint64 startTime, uint64 endTime, uint16 price) external;

    function buyWithEther(uint256 amount) external payable;

    function buyWithUSDT(uint256 amount) external;

    function claim() external;

    function getActiveRound() external view returns (Round memory);

    function getRoundIdCount() external view returns (uint256);

    function getClaimableAmount(address user) external view returns (uint256);

    function getLatestEtherPrice() external view returns (uint256);
}
