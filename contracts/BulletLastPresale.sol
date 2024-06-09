// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { MulticallUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import { IBulletLastPresale } from "./interfaces/IBulletLastPresale.sol";

contract BulletLastPresale is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    MulticallUpgradeable,
    IBulletLastPresale
{
    using SafeERC20 for IERC20;

    bytes32 public constant VERSION = "1.0.0";
    bytes32 public constant ROUND_MANAGER_ROLE = keccak256("ROUND_MANAGER_ROLE");

    uint256 private constant _MIN_ETHER_BUY_AMOUNT = 4 * 10 ** 16;
    uint256 private constant _MAX_ETHER_BUY_AMOUNT = 40 * 10 ** 16;
    uint256 private constant _MIN_USDT_BUY_AMOUNT = 100 * 10 ** 6;
    uint256 private constant _MAX_USDT_BUY_AMOUNT = 1_000 * 10 ** 6;
    uint8 private constant _VESTING_CLIFFS = 3;

    uint8 public activeRoundId;
    uint64 public vestingDuration;
    uint256 public allocatedAmount;
    IERC20 public saleToken;
    AggregatorV3Interface public etherPriceFeed;
    IERC20 public usdtToken;
    address public treasury;
    mapping(uint256 roundId => Round round) public rounds;
    uint8[] public roundIds;
    mapping(address user => mapping(uint256 roundId => Vesting[_VESTING_CLIFFS] vesting)) public userVestings;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address saleToken_,
        address etherPriceFeed_,
        address usdtToken_,
        address treasury_,
        uint64 vestingDuration_
    ) external initializer {
        ContextUpgradeable.__Context_init();
        AccessControlUpgradeable.__AccessControl_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        PausableUpgradeable.__Pausable_init();
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

        if (treasury_ == address(0)) {
            revert ZeroTreasury();
        }
        treasury = treasury_;

        if (vestingDuration_ == 0) {
            revert ZeroVestingDuration();
        }
        vestingDuration = vestingDuration_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ROUND_MANAGER_ROLE, _msgSender());
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setTreasury(address treasury_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury_ == address(0)) {
            revert ZeroTreasury();
        }

        treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    function setActiveRoundId(uint8 activeRoundId_) external onlyRole(ROUND_MANAGER_ROLE) {
        if (activeRoundId_ == 0 || activeRoundId_ == activeRoundId) {
            revert InvalidActiveRoundId(activeRoundId_);
        }

        activeRoundId = activeRoundId_;
        emit ActiveRoundIdSet(activeRoundId_);
    }

    function setAllocatedAmount(uint256 allocatedAmount_) external onlyRole(ROUND_MANAGER_ROLE) {
        allocatedAmount = allocatedAmount_;
        emit AllocatedAmountSet(allocatedAmount_);
    }

    function createRound(
        uint8 id,
        uint64 startTime,
        uint64 endTime,
        uint16 price
    ) external onlyRole(ROUND_MANAGER_ROLE) {
        if (id == 0) {
            revert ZeroRoundId();
        }
        if (startTime == 0 || endTime == 0 || startTime >= endTime) {
            revert InvalidTimePeriod(startTime, endTime);
        }
        if (price == 0) {
            revert ZeroPrice();
        }

        Round storage round = rounds[id];
        if (round.price > 0) {
            round.startTime = startTime;
            round.endTime = endTime;
            round.price = price;

            emit RoundUpdated(id, startTime, endTime, price);
            return;
        }

        rounds[id] = Round({ startTime: startTime, endTime: endTime, price: price });
        roundIds.push(id);

        emit RoundCreated(id, startTime, endTime, price);
    }

    function buyWithEther(uint256 amount) external payable nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        if (block.timestamp < activeRound.startTime || block.timestamp > activeRound.endTime) {
            revert InvalidBuyPeriod(block.timestamp, activeRound.startTime, activeRound.endTime);
        }

        uint256 etherAmount = (amount * activeRound.price * 10 ** 14) / getLatestEtherPrice();
        if (etherAmount < _MIN_ETHER_BUY_AMOUNT) {
            revert TooLowEtherBuyAmount(etherAmount, amount);
        }
        if (etherAmount > _MAX_ETHER_BUY_AMOUNT) {
            revert TooHighEtherBuyAmount(etherAmount, amount);
        }
        if (etherAmount > msg.value) {
            revert InsufficientEtherAmount(etherAmount, msg.value);
        }

        _handleUserVesting(_msgSender(), activeRound, amount);

        _sendEther(treasury, etherAmount);

        uint256 excessAmount = msg.value - etherAmount;
        if (excessAmount > 0) {
            _sendEther(_msgSender(), excessAmount);
        }

        emit BoughtWithEther(_msgSender(), activeRoundId, amount, etherAmount);
    }

    function buyWithUSDT(uint256 amount) external nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        if (block.timestamp < activeRound.startTime || block.timestamp > activeRound.endTime) {
            revert InvalidBuyPeriod(block.timestamp, activeRound.startTime, activeRound.endTime);
        }

        uint256 usdtAmount = (amount * activeRound.price) / 10 ** 16;
        if (usdtAmount < _MIN_USDT_BUY_AMOUNT) {
            revert TooLowUSDTBuyAmount(usdtAmount);
        }
        if (usdtAmount > _MAX_USDT_BUY_AMOUNT) {
            revert TooHighUSDTBuyAmount(usdtAmount);
        }

        _handleUserVesting(_msgSender(), activeRound, amount);

        usdtToken.safeTransferFrom(_msgSender(), treasury, usdtAmount);
        emit BoughtWithUSDT(_msgSender(), activeRoundId, amount, usdtAmount);
    }

    function claim(address user) external nonReentrant whenNotPaused {
        uint256 claimableAmount = 0;
        uint256 roundIdCount = roundIds.length;

        for (uint256 i = 0; i < roundIdCount; i++) {
            uint256 roundId = roundIds[i];
            Vesting[_VESTING_CLIFFS] storage vestings = userVestings[user][roundId];

            for (uint256 j = 0; j < _VESTING_CLIFFS; j++) {
                Vesting storage vesting = vestings[j];
                if (vesting.amount > 0 && block.timestamp >= vesting.startTime) {
                    claimableAmount += vesting.amount;
                    vesting.amount = 0;
                }
            }
        }

        if (claimableAmount == 0) {
            revert ZeroClaimableAmount(user);
        }

        saleToken.safeTransferFrom(treasury, user, claimableAmount);
        emit Claimed(user, claimableAmount);
    }

    function getActiveRound() external view returns (Round memory) {
        return _getActiveRound();
    }

    function getClaimableAmount(address user) external view returns (uint256) {
        uint256 claimableAmount = 0;
        uint256 roundIdCount = roundIds.length;

        for (uint256 i = 0; i < roundIdCount; i++) {
            uint256 roundId = roundIds[i];
            Vesting[_VESTING_CLIFFS] storage vestings = userVestings[user][roundId];

            for (uint256 j = 0; j < _VESTING_CLIFFS; j++) {
                Vesting storage vesting = vestings[j];
                if (vesting.amount > 0 && block.timestamp >= vesting.startTime) {
                    claimableAmount += vesting.amount;
                }
            }
        }

        return claimableAmount;
    }

    function getLatestEtherPrice() public view returns (uint256) {
        (, int256 price, , , ) = etherPriceFeed.latestRoundData();
        return uint256(price) * 10 ** 10;
    }

    function _handleUserVesting(address user, Round storage round, uint256 amount) private {
        if (amount > allocatedAmount) {
            revert InsufficientAllocatedAmount(amount, allocatedAmount);
        }
        allocatedAmount -= amount;

        uint256 vestingPartialAmount = amount / (_VESTING_CLIFFS + 1);
        Vesting[_VESTING_CLIFFS] storage vestings = userVestings[user][activeRoundId];

        for (uint256 i = 0; i < _VESTING_CLIFFS; i++) {
            uint64 cliff = uint64(i + 1) * vestingDuration;
            uint64 startTime = round.startTime + cliff;

            if (vestings[i].startTime > 0) {
                vestings[i].amount += vestingPartialAmount;
            } else {
                vestings[i] = Vesting({ amount: vestingPartialAmount, startTime: startTime });
            }
        }

        uint256 transferAmount = amount - vestingPartialAmount * _VESTING_CLIFFS;
        saleToken.safeTransferFrom(treasury, user, transferAmount);
    }

    function _sendEther(address to, uint256 amount) private {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = to.call{ value: amount }("");
        if (!success) {
            revert EtherTransferFailed(to, amount);
        }
    }

    function _getActiveRound() private view returns (Round storage) {
        Round storage round = rounds[activeRoundId];
        if (round.price == 0) {
            revert RoundNotFound();
        }
        return round;
    }
}
