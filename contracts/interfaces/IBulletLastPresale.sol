// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Round {
        uint16 id;
        uint64 startTime;
        uint64 endTime;
        uint16 price;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint64 startTime;
        uint64 endTime;
    }

    event TreasurySet(address indexed treasury);

    event ActiveRoundIdSet(uint256 activeRoundId);

    event RoundCreated(uint16 id, uint64 startTime, uint64 endTime, uint16 price);

    event BoughtWithEther(address indexed user, uint256 indexed roundId, uint256 amount, uint256 etherAmount);

    event BoughtWithUSDT(address indexed user, uint256 indexed roundId, uint256 amount, uint256 usdtAmount);

    event Claimed(address indexed user, uint256 indexed roundId, uint256 amount);

    error ZeroSaleToken();

    error ZeroPriceFeed();

    error ZeroUSDTToken();

    error ZeroTreasury();

    error ZeroPrice();

    error ZeroClaimAmount();

    error ZeroActiveRoundId();

    error ActiveRoundNotFound();

    error ActiveRoundIdAlreadySet(uint256 activeRoundId);

    error InvalidTimePeriod(uint256 startTime, uint256 endTime);

    error TooLowUSDTBuy(uint256 amount);

    error TooHighUSDTBuy(uint256 amount);

    error InvalidBuyPeriod(uint256 currentTime, uint256 startTime, uint256 endTime);

    error InsufficientEtherAmount(uint256 expectedAmount, uint256 actualAmount);

    error InsufficientCurrentBalance(uint256 currentBalance, uint256 amount);

    error EtherTransferFailed(address to, uint256 amount);

    function pause() external;

    function unpause() external;

    function setTreasury(address treasury) external;

    function setActiveRoundId(uint16 activeRoundId) external;

    function createRound(uint16 id, uint64 startTime, uint64 endTime, uint16 price) external;

    function buyWithEther(uint256 amount) external payable;

    function buyWithUSDT(uint256 amount) external;

    function claim(address user, uint16 roundId) external;

    function claimableAmount(address user, uint16 roundId) external view returns (uint256);

    function getActiveRound() external view returns (Round memory);

    function getLatestEtherPrice() external view returns (uint256);
}
