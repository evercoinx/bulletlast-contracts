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
        if (roundId == 0 || roundId > currentRoundId) {
            revert InvalidRoundId(roundId, currentRoundId);
        }
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

        if (priceFeed_ == address(0)) {
            revert ZeroPriceFeed();
        }
        if (usdt_ == address(0)) {
            revert ZeroUSDT();
        }

        priceFeed = AggregatorV3Interface(priceFeed_);
        usdt = IERC20(usdt_);
    }

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
    ) external onlyOwner {
        if (startTime <= block.timestamp || endTime > startTime) {
            revert InvalidTimePeriod(block.timestamp, startTime, endTime);
        }
        if (price == 0) {
            revert ZeroPrice();
        }
        if (allocatedAmount == 0) {
            revert ZeroTokensToSell();
        }
        if (tokenDecimals == 0) {
            revert ZeroTokenDecimals();
        }
        if (vestingStartTime < endTime) {
            revert InvalidVestingStartTime(vestingStartTime, endTime);
        }

        currentRoundId++;

        rounds[currentRoundId] = Round({
            saleToken: address(0),
            startTime: startTime,
            endTime: endTime,
            price: price,
            allocatedAmount: allocatedAmount,
            tokenDecimals: tokenDecimals,
            inSale: allocatedAmount,
            vestingStartTime: vestingStartTime,
            vestingCliff: vestingCliff,
            vestingPeriod: vestingPeriod,
            enableBuyWithEther: enableBuyWithEther,
            enableBuyWithUSDT: enableBuyWithUSDT
        });

        emit RoundCreated(
            currentRoundId,
            startTime,
            endTime,
            price,
            allocatedAmount,
            enableBuyWithEther,
            enableBuyWithUSDT
        );
    }

    function setSalePeriod(
        uint256 roundId,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner checkRoundId(roundId) {
        if (startTime == 0 && endTime == 0) {
            revert ZeroStartAndEndTime();
        }

        Round storage currentRound = rounds[roundId];
        if (startTime > 0) {
            if (block.timestamp >= startTime) {
                revert SaleInPast(block.timestamp, startTime);
            }
            if (block.timestamp >= currentRound.startTime) {
                revert SaleAlreadyStarted(block.timestamp, currentRound.startTime);
            }

            currentRound.startTime = startTime;
            emit RoundUpdated(bytes32("START"), currentRound.startTime, startTime, block.timestamp);
        }

        if (endTime > 0) {
            if (block.timestamp >= endTime) {
                revert SaleAlreadyEnded(block.timestamp, endTime);
            }
            if (endTime <= currentRound.startTime) {
                revert InvalidSaleEndTime(endTime, currentRound.startTime);
            }

            currentRound.endTime = endTime;
            emit RoundUpdated(bytes32("END"), currentRound.endTime, endTime, block.timestamp);
        }
    }

    function setVestingStartTime(uint256 roundId, uint256 vestingStartTime) external onlyOwner checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        if (vestingStartTime < currentRound.endTime) {
            revert InvalidVestingStartTime(vestingStartTime, currentRound.endTime);
        }

        rounds[roundId].vestingStartTime = vestingStartTime;
        emit RoundUpdated(
            bytes32("VESTING_START_TIME"),
            currentRound.vestingStartTime,
            vestingStartTime,
            block.timestamp
        );
    }

    function setSaleToken(uint256 roundId, address saleToken) external onlyOwner checkRoundId(roundId) {
        if (saleToken == address(0)) {
            revert ZeroSaleToken();
        }

        Round storage currentRound = rounds[roundId];
        rounds[roundId].saleToken = saleToken;
        emit RoundTokenAddressUpdated(currentRound.saleToken, saleToken, block.timestamp);
    }

    function setPrice(uint256 roundId, uint256 price) external onlyOwner checkRoundId(roundId) {
        if (price == 0) {
            revert ZeroPrice();
        }

        Round storage currentRound = rounds[roundId];
        if (currentRound.startTime <= block.timestamp) {
            revert SaleAlreadyStarted(block.timestamp, currentRound.startTime);
        }

        rounds[roundId].price = price;
        emit RoundUpdated(bytes32("PRICE"), rounds[roundId].price, price, block.timestamp);
    }

    function setEnableBuyWithEther(uint256 roundId, bool enableBuyWithEther) external onlyOwner checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        currentRound.enableBuyWithEther = enableBuyWithEther;

        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_ETH"),
            _toUint256(currentRound.enableBuyWithEther),
            _toUint256(enableBuyWithEther),
            block.timestamp
        );
    }

    function setEnableBuyWithUSDT(uint256 roundId, bool enableBuyWithUSDT) external onlyOwner checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        currentRound.enableBuyWithUSDT = enableBuyWithUSDT;

        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_USDT"),
            _toUint256(currentRound.enableBuyWithUSDT),
            _toUint256(enableBuyWithUSDT),
            block.timestamp
        );
    }

    function pauseRound(uint256 roundId) external onlyOwner checkRoundId(roundId) {
        if (pausedRounds[roundId]) {
            revert RoundAlreadyPaused(roundId);
        }

        pausedRounds[roundId] = true;
        emit RoundPaused(roundId, block.timestamp);
    }

    function unpauseRound(uint256 roundId) external onlyOwner checkRoundId(roundId) {
        if (!pausedRounds[roundId]) {
            revert RoundNotPaused(roundId);
        }

        pausedRounds[roundId] = false;
        emit RoundUnpaused(roundId, block.timestamp);
    }

    function buyWithEther(
        uint256 roundId,
        uint256 amount
    ) external payable nonReentrant checkRoundId(roundId) returns (bool) {
        if (pausedRounds[roundId]) {
            revert RoundAlreadyPaused(roundId);
        }

        Round storage currentRound = rounds[roundId];
        if (!currentRound.enableBuyWithEther) {
            revert BuyWithEtherForbidden(roundId);
        }
        _checkSale(currentRound, amount);

        uint256 usdPrice = amount * rounds[roundId].price;
        uint256 etherAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
        if (msg.value < etherAmount) {
            revert InsufficientEtherAmount(msg.value, etherAmount);
        }

        uint256 excess = msg.value - etherAmount;
        rounds[roundId].inSale -= amount;

        Vesting storage userVesting = userVestings[_msgSender()][roundId];
        if (userVesting.totalAmount > 0) {
            userVesting.totalAmount += (amount * currentRound.tokenDecimals);
        } else {
            userVestings[_msgSender()][roundId] = Vesting(
                (amount * currentRound.tokenDecimals),
                0,
                currentRound.vestingStartTime + currentRound.vestingCliff,
                currentRound.vestingStartTime + currentRound.vestingCliff + currentRound.vestingPeriod
            );
        }

        _sendValue(payable(owner()), etherAmount);
        if (excess > 0) {
            _sendValue(payable(_msgSender()), excess);
        }

        emit TokensBought(_msgSender(), roundId, address(0), amount, etherAmount, block.timestamp);
        return true;
    }

    function buyWithUSDT(uint256 roundId, uint256 amount) external nonReentrant checkRoundId(roundId) returns (bool) {
        if (pausedRounds[roundId]) {
            revert RoundAlreadyPaused(roundId);
        }

        Round storage currentRound = rounds[roundId];
        if (!currentRound.enableBuyWithUSDT) {
            revert BuyWithUSDTForbidden(roundId);
        }
        _checkSale(currentRound, amount);

        uint256 usdPrice = amount * rounds[roundId].price;
        usdPrice = usdPrice / (10 ** 12);
        rounds[roundId].inSale -= amount;

        Vesting storage userVesting = userVestings[_msgSender()][roundId];
        if (userVesting.totalAmount > 0) {
            userVesting.totalAmount += (amount * currentRound.tokenDecimals);
        } else {
            userVestings[_msgSender()][roundId] = Vesting(
                (amount * currentRound.tokenDecimals),
                0,
                currentRound.vestingStartTime + currentRound.vestingCliff,
                currentRound.vestingStartTime + currentRound.vestingCliff + currentRound.vestingPeriod
            );
        }

        uint256 allowance = usdt.allowance(_msgSender(), address(this));
        if (usdPrice > allowance) {
            revert InsufficientUSDTAllowance(allowance, usdPrice);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(usdt).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), owner(), usdPrice)
        );
        // solhint-disable-next-line custom-errors
        require(success, "Token payment failed");

        emit TokensBought(_msgSender(), roundId, address(usdt), amount, usdPrice, block.timestamp);
        return true;
    }

    // function claimMultiple(address[] calldata users, uint256 roundId) external returns (bool) {
    //     require(users.length > 0, "Zero users length");

    //     for (uint256 i; i < users.length; i++) {
    //         require(claim(users[i], roundId), "Claim failed");
    //     }
    //     return true;
    // }

    function etherBuyHelper(
        uint256 roundId,
        uint256 amount
    ) external view checkRoundId(roundId) returns (uint256 etherAmount) {
        uint256 usdPrice = amount * rounds[roundId].price;
        etherAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
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
        if (amount == 0) {
            revert ZeroClaimAmount();
        }

        uint256 currentBalance = IERC20(rounds[roundId].saleToken).balanceOf(address(this));
        if (amount > currentBalance) {
            revert InsufficientCurrentBalance(amount, currentBalance);
        }

        userVestings[user][roundId].claimedAmount += amount;

        bool status = IERC20(rounds[roundId].saleToken).transfer(user, amount);
        // solhint-disable-next-line custom-errors
        require(status, "Token transfer failed");

        emit TokensClaimed(user, roundId, amount, block.timestamp);
        return true;
    }

    function claimableAmount(address user, uint256 roundId) public view checkRoundId(roundId) returns (uint256) {
        Vesting memory userVesting = userVestings[user][roundId];
        uint256 amount = userVesting.totalAmount - userVesting.claimedAmount;

        if (block.timestamp < userVesting.claimStart) {
            return 0;
        }
        if (block.timestamp >= userVesting.claimEnd) {
            return amount;
        }

        uint256 monthsPassed = (block.timestamp - userVesting.claimStart) / MONTH;
        uint256 perMonthClaim = (userVesting.totalAmount * BASE_MULTIPLIER * MONTH) /
            (userVesting.claimEnd - userVesting.claimStart);
        uint256 amountToClaim = ((monthsPassed * perMonthClaim) / BASE_MULTIPLIER) - userVesting.claimedAmount;

        return amountToClaim;
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function _sendValue(address payable to, uint256 amount) private {
        if (address(this).balance >= amount) {
            revert InsufficientCurrentBalance(amount, address(this).balance);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{ value: amount }("");
        // solhint-disable-next-line custom-errors
        require(success, "ETH Payment failed");
    }

    function _checkSale(Round storage round, uint256 amount) private view {
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert InvalidBuyPeriod(block.timestamp, round.startTime, round.endTime);
        }
        if (amount == 0 || amount > round.inSale) {
            revert InvalidSaleAmount(amount, round.inSale);
        }
    }

    function _toUint256(bool b) private pure returns (uint256 n) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            n := b
        }
    }
}
