// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IBulletLastPresale {
    struct Round {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 allocatedAmount;
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 startTime;
        uint256 endTime;
    }

    event ActiveRoundIdSet(uint256 indexed activeRoundId);

    event SaleTokenSet(address indexed saleToken);

    event RoundCreated(
        uint256 id,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 allocatedAmount,
        uint256 vestingStartTime,
        uint256 vestingCliff,
        uint256 vestingPeriod
    );

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

    error ZeroPriceFeed();

    error ZeroUSDTToken();

    error ZeroPrice();

    error ZeroAllocatedAmount();

    error ZeroSaleToken();

    error ZeroClaimAmount();

    error NoActiveRoundFound();

    error ActiveRoundIdAlreadySet(uint256 activeRoundId);

    error InvalidTimePeriod(uint256 startTime, uint256 endTime);

    error InvalidBuyPeriod(uint256 currentTime, uint256 roundStartTime, uint256 roundEndTime);

    error InvalidSaleAmount(uint256 amount, uint256 roundAllocatedAmount);

    error InvalidVestingStartTime(uint256 vestingStartTime, uint256 roundEndTime);

    error InsufficientEtherAmount(uint256 expectedAmount, uint256 actualAmount);

    error InsufficientCurrentBalance(uint256 currentBalance, uint256 amount);

    error EtherTransferFailed(address to, uint256 amount);

    function setActiveRoundId(uint256 activeRoundId) external;

    function createRound(
        uint256 id,
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 allocatedAmount,
        uint256 vestingStartTime,
        uint256 vestingCliff,
        uint256 vestingPeriod
    ) external;

    function pause() external;

    function unpause() external;

    function buySaleTokenWithEther(uint256 amount) external payable;

    function buySaleTokenWithUSDT(uint256 amount) external;

    function claimSaleToken(uint256 roundId, address user) external;

    function claimableSaleTokenAmount(uint256 roundId, address user) external view returns (uint256);

    function getActiveRound() external view returns (Round memory);

    function getLatestEtherPrice() external view returns (uint256);
}
