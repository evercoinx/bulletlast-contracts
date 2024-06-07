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

    uint256 private constant _MIN_USDT_BUY_AMOUNT = 100 * 10 ** _USDT_TOKEN_DECIMALS;
    uint256 private constant _MAX_USDT_BUY_AMOUNT = 1_000 * 10 ** _USDT_TOKEN_DECIMALS;
    uint8 private constant _VESTING_CLIFFS = 3;
    uint8 private constant _USDT_TOKEN_DECIMALS = 6;

    uint16 public activeRoundId;
    IERC20 public saleToken;
    AggregatorV3Interface public etherPriceFeed;
    IERC20 public usdtToken;
    address public treasury;
    mapping(uint256 roundId => Round round) public rounds;
    mapping(address user => mapping(uint256 roundId => Vesting[_VESTING_CLIFFS] vesting)) public userVestings;

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
        uint16 price
    ) external onlyRole(ROUND_MANAGER_ROLE) {
        if (startTime == 0 || endTime == 0 || startTime >= endTime) {
            revert InvalidTimePeriod(startTime, endTime);
        }
        if (price == 0) {
            revert ZeroPrice();
        }

        rounds[id] = Round({ id: id, startTime: startTime, endTime: endTime, price: price });
        emit RoundCreated(id, startTime, endTime, price);
    }

    function buyWithEther(uint256 amount) external payable nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        if (block.timestamp < activeRound.startTime || block.timestamp > activeRound.endTime) {
            revert InvalidBuyPeriod(block.timestamp, activeRound.startTime, activeRound.endTime);
        }

        _handleUserVesting(_msgSender(), activeRound, amount);

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
        if (block.timestamp < activeRound.startTime || block.timestamp > activeRound.endTime) {
            revert InvalidBuyPeriod(block.timestamp, activeRound.startTime, activeRound.endTime);
        }

        uint256 usdtAmount = (amount * activeRound.price) / (10 ** 16);
        if (usdtAmount < _MIN_USDT_BUY_AMOUNT) {
            revert TooLowUSDTBuyAmount(usdtAmount);
        }
        if (usdtAmount > _MAX_USDT_BUY_AMOUNT) {
            revert TooHighUSDTBuyAmount(usdtAmount);
        }

        _handleUserVesting(_msgSender(), activeRound, amount);

        usdtToken.safeTransferFrom(_msgSender(), treasury, usdtAmount);

        emit BoughtWithUSDT(_msgSender(), activeRound.id, amount, usdtAmount);
    }

    function claim(address user, uint16 roundId) external nonReentrant whenNotPaused {
        uint256 claimableAmount = 0;
        Vesting[_VESTING_CLIFFS] storage vestings = userVestings[user][roundId];

        for (uint256 i = 0; i < _VESTING_CLIFFS; i++) {
            Vesting storage vesting = vestings[i];
            if (vesting.amount > 0 && block.timestamp >= vesting.startTime) {
                claimableAmount += vesting.amount;
                vesting.amount = 0;
            }
        }

        if (claimableAmount == 0) {
            revert ZeroClaimableAmount(user, roundId);
        }

        saleToken.safeTransfer(user, claimableAmount);

        emit Claimed(user, roundId, claimableAmount);
    }

    function getActiveRound() external view returns (Round memory) {
        return _getActiveRound();
    }

    function getClaimableAmount(address user, uint16 roundId) external view returns (uint256) {
        uint256 claimableAmount = 0;
        Vesting[_VESTING_CLIFFS] storage vestings = userVestings[user][roundId];

        for (uint256 i = 0; i < _VESTING_CLIFFS; i++) {
            Vesting storage vesting = vestings[i];
            if (vesting.amount > 0 && vesting.startTime >= block.timestamp) {
                claimableAmount += vesting.amount;
            }
        }

        return claimableAmount;
    }

    function getLatestEtherPrice() public view returns (uint256) {
        (, int256 price, , , ) = etherPriceFeed.latestRoundData();
        return uint256((price * (10 ** 10)));
    }

    function _handleUserVesting(address user, Round storage round, uint256 amount) private {
        uint256 vestingAmount = amount / (_VESTING_CLIFFS + 1);
        Vesting[_VESTING_CLIFFS] storage vestings = userVestings[_msgSender()][round.id];

        for (uint256 i = 0; i < _VESTING_CLIFFS; i++) {
            uint64 cliff = uint64(i + 1) * VESTING_DURATION;
            uint64 startTime = round.startTime + cliff;

            if (vestings[i].startTime > 0) {
                vestings[i].amount += vestingAmount;
            } else {
                vestings[i] = Vesting({ amount: vestingAmount, startTime: startTime });
            }
        }

        uint256 unlockedAmount = amount - vestingAmount * _VESTING_CLIFFS;
        saleToken.safeTransferFrom(treasury, user, unlockedAmount);
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
}
