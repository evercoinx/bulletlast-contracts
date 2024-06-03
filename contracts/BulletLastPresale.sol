// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IBulletLastPresale } from "./interfaces/IBulletLastPresale.sol";

contract BulletLastPresale is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    IBulletLastPresale
{
    uint256 public constant BASE_MULTIPLIER = 10 ** 18;
    uint256 public constant MONTH = 30 days;

    uint256 public currentRoundId;
    AggregatorV3Interface public priceFeed;
    IERC20 public usdt;

    mapping(uint256 roundId => Round round) public rounds;
    mapping(uint256 roundId => bool paused) public pausedRounds;
    mapping(address user => mapping(uint256 roundId => Vesting vesting)) public userVestings;

    modifier checkRoundId(uint256 roundId) {
        require(roundId > 0 && roundId <= currentRoundId, "Invalid round id");
        _;
    }

    modifier checkSaleState(uint256 roundId, uint256 amount) {
        require(
            block.timestamp >= rounds[roundId].startTime && block.timestamp <= rounds[roundId].endTime,
            "Invalid time for buying"
        );
        require(amount > 0 && amount <= rounds[roundId].inSale, "Invalid sale amount");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address priceFeed_, address usdt_) external initializer {
        ContextUpgradeable.__Context_init();
        OwnableUpgradeable.__Ownable_init(_msgSender());
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        require(priceFeed_ != address(0), "Zero aggregator address");
        require(usdt_ != address(0), "Zero USDT address");

        priceFeed = AggregatorV3Interface(priceFeed_);
        usdt = IERC20(usdt_);
    }

    function createRound(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 tokensToSell,
        uint256 baseDecimals,
        uint256 vestingStartTime,
        uint256 vestingCliff,
        uint256 vestingPeriod,
        uint256 enableBuyWithEther,
        uint256 enableBuyWithUSDT
    ) external onlyOwner {
        require(startTime > block.timestamp && endTime > startTime, "Invalid time");
        require(price > 0, "Zero price");
        require(tokensToSell > 0, "Zero tokens to sell");
        require(baseDecimals > 0, "Zero decimals for the token");
        require(vestingStartTime >= endTime, "Unexpected vesting start");

        currentRoundId++;

        rounds[currentRoundId] = Round({
            saleToken: address(0),
            startTime: startTime,
            endTime: endTime,
            price: price,
            tokensToSell: tokensToSell,
            baseDecimals: baseDecimals,
            inSale: tokensToSell,
            vestingStartTime: vestingStartTime,
            vestingCliff: vestingCliff,
            vestingPeriod: vestingPeriod,
            enableBuyWithEther: enableBuyWithEther,
            enableBuyWithUSDT: enableBuyWithUSDT
        });

        emit RoundCreated(currentRoundId, tokensToSell, startTime, endTime, enableBuyWithEther, enableBuyWithUSDT);
    }

    function setSalePeriod(
        uint256 roundId,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner checkRoundId(roundId) {
        require(startTime > 0 || endTime > 0, "Invalid parameters");

        if (startTime > 0) {
            require(block.timestamp < rounds[roundId].startTime, "Sale already started");
            require(block.timestamp < startTime, "Sale time in past");

            uint256 prevValue = rounds[roundId].startTime;
            rounds[roundId].startTime = startTime;
            emit RoundUpdated(bytes32("START"), prevValue, startTime, block.timestamp);
        }

        if (endTime > 0) {
            require(block.timestamp < rounds[roundId].endTime, "Sale already ended");
            require(endTime > rounds[roundId].startTime, "Invalid endTime");

            uint256 prevValue = rounds[roundId].endTime;
            rounds[roundId].endTime = endTime;
            emit RoundUpdated(bytes32("END"), prevValue, endTime, block.timestamp);
        }
    }

    function setVestingStartTime(uint256 roundId, uint256 vestingStartTime) external onlyOwner checkRoundId(roundId) {
        require(vestingStartTime >= rounds[roundId].endTime, "Unexpected vesting start");

        uint256 prevValue = rounds[roundId].vestingStartTime;
        rounds[roundId].vestingStartTime = vestingStartTime;
        emit RoundUpdated(bytes32("VESTING_START_TIME"), prevValue, vestingStartTime, block.timestamp);
    }

    function setSaleToken(uint256 roundId, address saleToken) external onlyOwner checkRoundId(roundId) {
        require(saleToken != address(0), "Zero token address");

        address prevValue = rounds[roundId].saleToken;
        rounds[roundId].saleToken = saleToken;
        emit RoundTokenAddressUpdated(prevValue, saleToken, block.timestamp);
    }

    function setPrice(uint256 roundId, uint256 price) external onlyOwner checkRoundId(roundId) {
        require(price > 0, "Zero price");
        require(rounds[roundId].startTime > block.timestamp, "Sale already started");

        rounds[roundId].price = price;
        emit RoundUpdated(bytes32("PRICE"), rounds[roundId].price, price, block.timestamp);
    }

    function setEnableBuyWithEther(
        uint256 roundId,
        uint256 enableBuyWithEther
    ) external onlyOwner checkRoundId(roundId) {
        rounds[roundId].enableBuyWithEther = enableBuyWithEther;
        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_ETH"),
            rounds[roundId].enableBuyWithEther,
            enableBuyWithEther,
            block.timestamp
        );
    }

    function setEnableBuyWithUSDT(uint256 roundId, uint256 enableBuyWithUSDT) external onlyOwner checkRoundId(roundId) {
        rounds[roundId].enableBuyWithUSDT = enableBuyWithUSDT;
        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_USDT"),
            rounds[roundId].enableBuyWithUSDT,
            enableBuyWithUSDT,
            block.timestamp
        );
    }

    function pauseRound(uint256 roundId) external onlyOwner checkRoundId(roundId) {
        require(!pausedRounds[roundId], "Already paused");

        pausedRounds[roundId] = true;
        emit RoundPaused(roundId, block.timestamp);
    }

    function unpauseRound(uint256 roundId) external onlyOwner checkRoundId(roundId) {
        require(pausedRounds[roundId], "Not paused");

        pausedRounds[roundId] = false;
        emit RoundUnpaused(roundId, block.timestamp);
    }

    function buyWithEther(
        uint256 roundId,
        uint256 amount
    ) external payable checkRoundId(roundId) checkSaleState(roundId, amount) nonReentrant returns (bool) {
        require(!pausedRounds[roundId], "Round paused");
        require(rounds[roundId].enableBuyWithEther > 0, "Not allowed to buy with ETH");

        uint256 usdPrice = amount * rounds[roundId].price;
        uint256 ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");

        uint256 excess = msg.value - ethAmount;
        rounds[roundId].inSale -= amount;
        Round memory currentRound = rounds[roundId];

        if (userVestings[_msgSender()][roundId].totalAmount > 0) {
            userVestings[_msgSender()][roundId].totalAmount += (amount * currentRound.baseDecimals);
        } else {
            userVestings[_msgSender()][roundId] = Vesting(
                (amount * currentRound.baseDecimals),
                0,
                currentRound.vestingStartTime + currentRound.vestingCliff,
                currentRound.vestingStartTime + currentRound.vestingCliff + currentRound.vestingPeriod
            );
        }

        _sendValue(payable(owner()), ethAmount);
        if (excess > 0) {
            _sendValue(payable(_msgSender()), excess);
        }

        emit TokensBought(_msgSender(), roundId, address(0), amount, ethAmount, block.timestamp);
        return true;
    }

    function buyWithUSDT(
        uint256 roundId,
        uint256 amount
    ) external checkRoundId(roundId) checkSaleState(roundId, amount) returns (bool) {
        require(!pausedRounds[roundId], "Round paused");
        require(rounds[roundId].enableBuyWithUSDT > 0, "Not allowed to buy with USDT");

        uint256 usdPrice = amount * rounds[roundId].price;
        usdPrice = usdPrice / (10 ** 12);
        rounds[roundId].inSale -= amount;

        Round memory currentRound = rounds[roundId];
        Vesting storage userVesting = userVestings[_msgSender()][roundId];

        if (userVesting.totalAmount > 0) {
            userVesting.totalAmount += (amount * currentRound.baseDecimals);
        } else {
            userVestings[_msgSender()][roundId] = Vesting(
                (amount * currentRound.baseDecimals),
                0,
                currentRound.vestingStartTime + currentRound.vestingCliff,
                currentRound.vestingStartTime + currentRound.vestingCliff + currentRound.vestingPeriod
            );
        }

        uint256 allowance = usdt.allowance(_msgSender(), address(this));
        require(usdPrice <= allowance, "Insufficient USDT allowance");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(usdt).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), owner(), usdPrice)
        );
        require(success, "Token payment failed");

        emit TokensBought(_msgSender(), roundId, address(usdt), amount, usdPrice, block.timestamp);
        return true;
    }

    function claimMultiple(address[] calldata users, uint256 roundId) external returns (bool) {
        require(users.length > 0, "Zero users length");

        for (uint256 i; i < users.length; i++) {
            require(claim(users[i], roundId), "Claim failed");
        }
        return true;
    }

    function etherBuyHelper(
        uint256 roundId,
        uint256 amount
    ) external view checkRoundId(roundId) returns (uint256 ethAmount) {
        uint256 usdPrice = amount * rounds[roundId].price;
        ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
    }

    function usdtBuyHelper(
        uint256 roundId,
        uint256 amount
    ) external view checkRoundId(roundId) returns (uint256 usdPrice) {
        usdPrice = amount * rounds[roundId].price;
        usdPrice = usdPrice / (10 ** 12);
    }

    function claim(address user, uint256 roundId) public returns (bool) {
        uint256 amount = claimableAmount(user, roundId);
        require(amount > 0, "Zero claim amount");
        require(rounds[roundId].saleToken != address(0), "Round token address not set");
        require(amount <= IERC20(rounds[roundId].saleToken).balanceOf(address(this)), "Not enough tokens in contract");

        userVestings[user][roundId].claimedAmount += amount;
        bool status = IERC20(rounds[roundId].saleToken).transfer(user, amount);
        require(status, "Token transfer failed");

        emit TokensClaimed(user, roundId, amount, block.timestamp);
        return true;
    }

    function claimableAmount(address user, uint256 roundId) public view checkRoundId(roundId) returns (uint256) {
        Vesting memory _user = userVestings[user][roundId];
        require(_user.totalAmount > 0, "Nothing to claim");

        uint256 amount = _user.totalAmount - _user.claimedAmount;
        require(amount > 0, "Already claimed");

        if (block.timestamp < _user.claimStart) {
            return 0;
        }
        if (block.timestamp >= _user.claimEnd) {
            return amount;
        }

        uint256 monthsPassed = (block.timestamp - _user.claimStart) / MONTH;
        uint256 perMonthClaim = (_user.totalAmount * BASE_MULTIPLIER * MONTH) / (_user.claimEnd - _user.claimStart);
        uint256 amountToClaim = ((monthsPassed * perMonthClaim) / BASE_MULTIPLIER) - _user.claimedAmount;

        return amountToClaim;
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function _sendValue(address payable to, uint256 amount) private {
        require(address(this).balance >= amount, "Low balance");
        // slither-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{ value: amount }("");
        require(success, "ETH Payment failed");
    }
}
