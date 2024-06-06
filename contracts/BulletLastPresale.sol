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

    uint8 private constant _USDT_TOKEN_DECIMALS = 6;

    uint16 public activeRoundId;
    IERC20 public saleToken;
    AggregatorV3Interface public etherPriceFeed;
    IERC20 public usdtToken;
    mapping(uint256 roundId => Round round) public rounds;
    mapping(address user => mapping(uint256 roundId => Vesting vesting)) public userVestings;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address saleToken_, address etherPriceFeed_, address usdtToken_) external initializer {
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

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ROUND_MANAGER_ROLE, _msgSender());
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
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
        uint16 price,
        uint256 allocatedAmount,
        uint64 startTime,
        uint64 endTime,
        uint64 vestingStartTime,
        uint64 vestingPeriod
    ) external onlyRole(ROUND_MANAGER_ROLE) {
        if (startTime == 0 || endTime == 0 || endTime >= startTime) {
            revert InvalidTimePeriod(startTime, endTime);
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

        rounds[activeRoundId] = Round({
            id: id,
            allocatedAmount: allocatedAmount,
            startTime: startTime,
            endTime: endTime,
            price: price,
            vestingStartTime: vestingStartTime,
            vestingPeriod: vestingPeriod
        });

        emit RoundCreated(activeRoundId, price, allocatedAmount, startTime, endTime, vestingStartTime, vestingPeriod);
    }

    function buySaleTokenWithEther(uint256 amount) external payable nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        _checkSale(activeRound, amount);

        uint256 usdPrice = amount * rounds[activeRound.id].price;
        uint256 etherAmount = (usdPrice * 1 ether) / getLatestEtherPrice();
        if (etherAmount > msg.value) {
            revert InsufficientEtherAmount(etherAmount, msg.value);
        }

        rounds[activeRound.id].allocatedAmount -= amount;

        for (uint256 i = 0; i < 4; i++) {
            _setUserVesting(activeRound, amount, i);
        }

        _sendEther(address(this), etherAmount);

        uint256 excesses = msg.value - etherAmount;
        if (excesses > 0) {
            _sendEther(_msgSender(), excesses);
        }

        emit SaleTokenWithEtherBought(_msgSender(), activeRound.id, address(0), amount, etherAmount);
    }

    function buySaleTokenWithUSDT(uint256 amount) external nonReentrant whenNotPaused {
        Round storage activeRound = _getActiveRound();
        _checkSale(activeRound, amount);

        uint256 usdPrice = amount * activeRound.price;
        uint256 usdtAmount = usdPrice / (10 ** 12);

        activeRound.allocatedAmount -= amount;

        for (uint256 i = 0; i < 4; i++) {
            _setUserVesting(activeRound, amount, i);
        }

        usdtToken.safeTransferFrom(_msgSender(), address(this), usdtAmount);

        emit SaleTokenWithUSDTBought(_msgSender(), activeRound.id, address(usdtToken), amount, usdtAmount);
    }

    function claimSaleToken(address user, uint256 roundId) external nonReentrant whenNotPaused {
        uint256 amount = claimableSaleTokenAmount(user, roundId);
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

    function getActiveRound() external view returns (Round memory) {
        return _getActiveRound();
    }

    function claimableSaleTokenAmount(address user, uint256 roundId) public view returns (uint256) {
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

    function _setUserVesting(Round storage round, uint256 amount, uint256 cliff) private {
        if (cliff > 0) {
            userVestings[_msgSender()][round.id].totalAmount += (amount * _USDT_TOKEN_DECIMALS);
        } else {
            uint256 startTime = round.vestingStartTime + cliff * 30 days;
            userVestings[_msgSender()][round.id] = Vesting({
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

    function _getActiveRound() private view returns (Round storage) {
        Round storage round = rounds[activeRoundId];
        if (round.startTime == 0) {
            revert NoActiveRoundFound();
        }
        return round;
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
