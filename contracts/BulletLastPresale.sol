// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IBulletLastPresale } from "./interfaces/IBulletLastPresale.sol";

contract BulletLastPresale is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable,
    IBulletLastPresale
{
    using SafeERC20 for IERC20;
    using BitMaps for BitMaps.BitMap;

    bytes32 public constant VERSION = "1.0.0";
    bytes32 public constant ROUND_MANAGER_ROLE = keccak256("ROUND_MANAGER_ROLE");

    uint8 private constant _USDT_TOKEN_DECIMALS = 6;

    uint256 public currentRoundId;
    IERC20 public saleToken;
    AggregatorV3Interface public etherPriceFeed;
    IERC20 public usdtToken;
    mapping(uint256 roundId => Round round) public rounds;
    mapping(address user => mapping(uint256 roundId => Vesting vesting)) public userVestings;
    BitMaps.BitMap private _pausedRounds;

    modifier checkRoundId(uint256 roundId) {
        if (roundId == 0 || roundId > currentRoundId) {
            revert InvalidRoundId(roundId, currentRoundId);
        }
        _;
    }

    modifier whenNotPaused(uint256 roundId) {
        if (_pausedRounds.get(roundId)) {
            revert RoundAlreadyPaused(roundId);
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address saleToken_, address etherPriceFeed_, address usdtToken_) external initializer {
        ContextUpgradeable.__Context_init();
        AccessControlUpgradeable.__AccessControl_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        MulticallUpgradeable.__Multicall_init();

        if (saleToken_ == address(0)) {
            revert ZeroSaleToken();
        }
        saleToken = IERC20(saleToken_);

        if (etherPriceFeed_ == address(0)) {
            revert ZeroPriceFeed();
        }
        etherPriceFeed = AggregatorV3Interface(etherPriceFeed_);

        if (usdtToken_ == address(0)) {
            revert ZeroUSDTToken();
        }
        usdtToken = IERC20(usdtToken_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ROUND_MANAGER_ROLE, _msgSender());
    }

    function createRound(
        uint256 startTime,
        uint256 endTime,
        uint256 price,
        uint256 allocatedAmount,
        uint256 vestingStartTime,
        uint256 vestingCliff,
        uint256 vestingPeriod,
        bool enableBuyWithEther,
        bool enableBuyWithUSDT
    ) external onlyRole(ROUND_MANAGER_ROLE) {
        if (startTime <= block.timestamp || endTime > startTime) {
            revert InvalidTimePeriod(block.timestamp, startTime, endTime);
        }
        if (price == 0) {
            revert ZeroPrice();
        }
        if (allocatedAmount == 0) {
            revert ZeroAllocatedAmount();
        }
        if (vestingStartTime < endTime) {
            revert InvalidVestingStartTime(vestingStartTime, endTime);
        }

        currentRoundId++;

        rounds[currentRoundId] = Round({
            startTime: startTime,
            endTime: endTime,
            price: price,
            allocatedAmount: allocatedAmount,
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
            vestingStartTime,
            vestingCliff,
            vestingPeriod,
            enableBuyWithEther,
            enableBuyWithUSDT
        );
    }

    function setSaleToken(address saleToken_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (saleToken_ == address(0)) {
            revert ZeroSaleToken();
        }

        saleToken = saleToken;
        emit SaleTokenSet(saleToken_);
    }

    function setSalePeriod(
        uint256 roundId,
        uint256 startTime,
        uint256 endTime
    ) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
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
            emit RoundUpdated(bytes32("START_TIME"), currentRound.startTime, startTime);
        }

        if (endTime > 0) {
            if (block.timestamp >= endTime) {
                revert SaleAlreadyEnded(block.timestamp, endTime);
            }
            if (endTime <= currentRound.startTime) {
                revert InvalidSaleEndTime(endTime, currentRound.startTime);
            }

            currentRound.endTime = endTime;
            emit RoundUpdated(bytes32("END_TIME"), currentRound.endTime, endTime);
        }
    }

    function setPrice(uint256 roundId, uint256 price) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
        if (price == 0) {
            revert ZeroPrice();
        }

        Round storage currentRound = rounds[roundId];
        if (block.timestamp >= currentRound.startTime) {
            revert SaleAlreadyStarted(block.timestamp, currentRound.startTime);
        }

        rounds[roundId].price = price;
        emit RoundUpdated(bytes32("PRICE"), rounds[roundId].price, price);
    }

    function setVestingStartTime(
        uint256 roundId,
        uint256 vestingStartTime
    ) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        if (vestingStartTime < currentRound.endTime) {
            revert InvalidVestingStartTime(vestingStartTime, currentRound.endTime);
        }

        rounds[roundId].vestingStartTime = vestingStartTime;
        emit RoundUpdated(bytes32("VESTING_START_TIME"), currentRound.vestingStartTime, vestingStartTime);
    }

    function setEnableBuyWithEther(
        uint256 roundId,
        bool enableBuyWithEther
    ) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        currentRound.enableBuyWithEther = enableBuyWithEther;

        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_ETHER"),
            _toUint256(currentRound.enableBuyWithEther),
            _toUint256(enableBuyWithEther)
        );
    }

    function setEnableBuyWithUSDT(
        uint256 roundId,
        bool enableBuyWithUSDT
    ) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
        Round storage currentRound = rounds[roundId];
        currentRound.enableBuyWithUSDT = enableBuyWithUSDT;

        emit RoundUpdated(
            bytes32("ENABLE_BUY_WITH_USDT"),
            _toUint256(currentRound.enableBuyWithUSDT),
            _toUint256(enableBuyWithUSDT)
        );
    }

    function pauseRound(
        uint256 roundId
    ) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) whenNotPaused(roundId) {
        _pausedRounds.set(roundId);
        emit RoundPaused(roundId);
    }

    function unpauseRound(uint256 roundId) external onlyRole(ROUND_MANAGER_ROLE) checkRoundId(roundId) {
        if (!_pausedRounds.get(roundId)) {
            revert RoundNotPaused(roundId);
        }

        _pausedRounds.unset(roundId);
        emit RoundUnpaused(roundId);
    }

    function buySaleTokenWithEther(
        uint256 roundId,
        uint256 amount
    ) external payable nonReentrant checkRoundId(roundId) whenNotPaused(roundId) {
        Round storage currentRound = rounds[roundId];
        if (!currentRound.enableBuyWithEther) {
            revert BuyWithEtherForbidden(roundId);
        }
        _checkSale(currentRound, amount);

        uint256 usdPrice = amount * rounds[roundId].price;
        uint256 etherAmount = (usdPrice * 1 ether) / getLatestEtherPrice();
        if (etherAmount > msg.value) {
            revert InsufficientEtherAmount(etherAmount, msg.value);
        }

        rounds[roundId].allocatedAmount -= amount;
        _setUserVesting(roundId, currentRound, amount);

        _sendEther(address(this), etherAmount);

        uint256 excesses = msg.value - etherAmount;
        if (excesses > 0) {
            _sendEther(_msgSender(), excesses);
        }

        emit SaleTokenWithEtherBought(_msgSender(), roundId, address(0), amount, etherAmount);
    }

    function buySaleTokenWithUSDT(
        uint256 roundId,
        uint256 amount
    ) external nonReentrant checkRoundId(roundId) whenNotPaused(roundId) {
        Round storage currentRound = rounds[roundId];
        if (!currentRound.enableBuyWithUSDT) {
            revert BuyWithUSDTForbidden(roundId);
        }
        _checkSale(currentRound, amount);

        uint256 usdPrice = amount * rounds[roundId].price;
        uint256 usdtAmount = usdPrice / (10 ** 12);
        rounds[roundId].allocatedAmount -= amount;

        _setUserVesting(roundId, currentRound, amount);

        usdtToken.safeTransferFrom(_msgSender(), address(this), usdtAmount);

        emit SaleTokenWithUSDTBought(_msgSender(), roundId, address(usdtToken), amount, usdtAmount);
    }

    function claimSaleToken(uint256 roundId, address user) external nonReentrant {
        uint256 amount = claimableSaleTokenAmount(roundId, user);
        if (amount == 0) {
            revert ZeroClaimAmount();
        }

        uint256 currentBalance = saleToken.balanceOf(address(this));
        if (currentBalance < amount) {
            revert InsufficientCurrentBalance(currentBalance, amount);
        }

        userVestings[user][roundId].claimedAmount += amount;

        saleToken.safeTransfer(user, amount);

        emit SaleTokenClaimed(user, roundId, amount);
    }

    function claimableSaleTokenAmount(
        uint256 roundId,
        address user
    ) public view checkRoundId(roundId) returns (uint256) {
        Vesting memory userVesting = userVestings[user][roundId];
        uint256 amount = userVesting.totalAmount - userVesting.claimedAmount;

        if (block.timestamp < userVesting.startTime) {
            return 0;
        }
        if (block.timestamp >= userVesting.endTime) {
            return amount;
        }

        uint256 passedMonths = (block.timestamp - userVesting.startTime) / 30 days;
        uint256 monthlyClaim = (userVesting.totalAmount * 1 ether * 30 days) /
            (userVesting.endTime - userVesting.startTime);

        return ((passedMonths * monthlyClaim) / 1 ether) - userVesting.claimedAmount;
    }

    function getLatestEtherPrice() public view returns (uint256) {
        (, int256 price, , , ) = etherPriceFeed.latestRoundData();
        return uint256((price * (10 ** 10)));
    }

    function _setUserVesting(uint256 roundId, Round storage round, uint256 amount) private {
        Vesting storage userVesting = userVestings[_msgSender()][roundId];
        if (userVesting.totalAmount > 0) {
            userVesting.totalAmount += (amount * _USDT_TOKEN_DECIMALS);
        } else {
            uint256 startTime = round.vestingStartTime + round.vestingCliff;
            userVestings[_msgSender()][roundId] = Vesting({
                totalAmount: amount * _USDT_TOKEN_DECIMALS,
                claimedAmount: 0,
                startTime: startTime,
                endTime: startTime + round.vestingPeriod
            });
        }
    }

    function _sendEther(address to, uint256 amount) private {
        if (address(this).balance >= amount) {
            revert InsufficientCurrentBalance(address(this).balance, amount);
        }

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{ value: amount }("");
        if (!success) {
            revert EtherTransferFailed(to, amount);
        }
    }

    function _checkSale(Round storage round, uint256 amount) private view {
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert InvalidBuyPeriod(block.timestamp, round.startTime, round.endTime);
        }
        if (amount == 0 || amount > round.allocatedAmount) {
            revert InvalidSaleAmount(amount, round.allocatedAmount);
        }
    }

    function _toUint256(bool b) private pure returns (uint256 n) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            n := b
        }
    }
}
