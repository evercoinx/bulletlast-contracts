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
    uint64 public constant VESTING_DURATION = 30 days;
    uint16 public constant MIN_USD_BUY = 100;
    uint16 public constant MAX_USD_BUY = 1_000;

    uint8 private constant _TOTAL_VESTING_CLIFFS = 4;
    uint8 private constant _USDT_TOKEN_DECIMALS = 6;

    uint16 public activeRoundId;
    IERC20 public saleToken;
    AggregatorV3Interface public etherPriceFeed;
    IERC20 public usdtToken;
    address public treasury;
    mapping(uint256 roundId => Round round) public rounds;
    mapping(address user => mapping(uint256 roundId => Vesting vesting)) public userVestings;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address saleToken_,
        address etherPriceFeed_,
        address usdtToken_,
        address treasury_
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

    function setActiveRoundId(uint16 activeRoundId_) external onlyRole(ROUND_MANAGER_ROLE) {
        if (activeRoundId_ == activeRoundId) {
            revert ActiveRoundIdAlreadySet(activeRoundId_);
        }

        activeRoundId = activeRoundId_;
        emit ActiveRoundIdSet(activeRoundId_);
    }

    function createRound(
        uint16 id,
        uint64 startTime,
        uint64 endTime,
        uint256 price
    ) external onlyRole(ROUND_MANAGER_ROLE) {
        if (startTime == 0 || endTime == 0 || endTime >= startTime) {
            revert InvalidTimePeriod(startTime, endTime);
        }
        if (price == 0) {
            revert ZeroPrice();
        }

        rounds[id] = Round({ id: id, startTime: startTime, endTime: endTime, price: price });
        emit RoundCreated(activeRoundId, startTime, endTime, price);
    }

    function buyWithEther(uint256 amount) external payable nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        _checkSale(activeRound, amount);

        for (uint8 i = 0; i < _TOTAL_VESTING_CLIFFS; ) {
            _setUserVesting(activeRound, amount / _TOTAL_VESTING_CLIFFS, i);

            unchecked {
                ++i;
            }
        }

        uint256 etherAmount = (amount * activeRound.price * 1 ether) / getLatestEtherPrice();
        if (etherAmount > msg.value) {
            revert InsufficientEtherAmount(etherAmount, msg.value);
        }

        _sendEther(treasury, etherAmount);

        uint256 excesses = msg.value - etherAmount;
        if (excesses > 0) {
            _sendEther(_msgSender(), excesses);
        }

        emit BoughtWithEther(_msgSender(), activeRound.id, amount, etherAmount);
    }

    function buyWithUSDT(uint256 amount) external nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        _checkSale(activeRound, amount);

        for (uint8 i = 0; i < _TOTAL_VESTING_CLIFFS; ) {
            _setUserVesting(activeRound, amount / _TOTAL_VESTING_CLIFFS, i);

            unchecked {
                ++i;
            }
        }

        uint256 usdtAmount = (amount * activeRound.price) / (10 ** 12);
        usdtToken.safeTransferFrom(_msgSender(), treasury, usdtAmount);

        emit BoughtWithUSDT(_msgSender(), activeRound.id, amount, usdtAmount);
    }

    function claim(address user, uint16 roundId) external nonReentrant whenNotPaused {
        uint256 amount = claimableAmount(user, roundId);
        if (amount == 0) {
            revert ZeroClaimAmount();
        }

        uint256 currentBalance = saleToken.balanceOf(address(this));
        if (currentBalance < amount) {
            revert InsufficientCurrentBalance(currentBalance, amount);
        }

        userVestings[user][roundId].claimedAmount += amount;

        saleToken.safeTransfer(user, amount);

        emit Claimed(user, roundId, amount);
    }

    function getActiveRound() external view returns (Round memory) {
        return _getActiveRound();
    }

    function claimableAmount(address user, uint16 roundId) public view returns (uint256) {
        Vesting memory userVesting = userVestings[user][roundId];
        if (block.timestamp < userVesting.startTime) {
            return 0;
        }

        uint256 amount = userVesting.totalAmount - userVesting.claimedAmount;
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

    function _setUserVesting(Round storage round, uint256 amount, uint8 cliffNumber) private {
        if (cliffNumber > 0) {
            userVestings[_msgSender()][round.id].totalAmount += (amount * _USDT_TOKEN_DECIMALS);
        } else {
            uint64 startTime = round.startTime + cliffNumber * VESTING_DURATION;
            userVestings[_msgSender()][round.id] = Vesting({
                totalAmount: amount * _USDT_TOKEN_DECIMALS,
                claimedAmount: 0,
                startTime: startTime,
                endTime: startTime + VESTING_DURATION
            });
        }
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
        if (round.startTime == 0) {
            revert ActiveRoundNotFound();
        }

        return round;
    }

    function _checkSale(Round storage round, uint256 amount) private view {
        if (amount == 0) {
            revert ZeroBuyAmount();
        }
        if (block.timestamp < round.startTime || block.timestamp > round.endTime) {
            revert InvalidBuyPeriod(block.timestamp, round.startTime, round.endTime);
        }
    }
}
