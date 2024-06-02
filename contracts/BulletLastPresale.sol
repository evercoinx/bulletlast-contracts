// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
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
    struct Presale {
        address saleToken;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256 tokensToSell;
        uint256 baseDecimals;
        uint256 inSale;
        uint256 vestingStartTime;
        uint256 vestingCliff;
        uint256 vestingPeriod;
        uint256 enableBuyWithEth;
        uint256 enableBuyWithUsdt;
    }

    struct Vesting {
        uint256 totalAmount;
        uint256 claimedAmount;
        uint256 claimStart;
        uint256 claimEnd;
    }

    uint256 public presaleId;
    uint256 public BASE_MULTIPLIER;
    uint256 public MONTH;

    IERC20 public USDTInterface;
    AggregatorV3Interface internal aggregatorInterface;

    mapping(uint256 => bool) public paused;
    mapping(uint256 => Presale) public presale;
    mapping(address => mapping(uint256 => Vesting)) public userVesting;

    modifier checkPresaleId(uint256 _id) {
        require(_id > 0 && _id <= presaleId, "Invalid presale id");
        _;
    }

    modifier checkSaleState(uint256 _id, uint256 amount) {
        require(
            block.timestamp >= presale[_id].startTime && block.timestamp <= presale[_id].endTime,
            "Invalid time for buying"
        );
        require(amount > 0 && amount <= presale[_id].inSale, "Invalid sale amount");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address oracle_, address usdt_) external initializer {
        ContextUpgradeable.__Context_init();
        OwnableUpgradeable.__Ownable_init(_msgSender());
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        require(oracle_ != address(0), "Zero aggregator address");
        require(usdt_ != address(0), "Zero USDT address");

        aggregatorInterface = AggregatorV3Interface(oracle_);
        USDTInterface = IERC20(usdt_);
        BASE_MULTIPLIER = (10 ** 18);
        MONTH = 30 days;
    }

    function createPresale(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _price,
        uint256 _tokensToSell,
        uint256 _baseDecimals,
        uint256 _vestingStartTime,
        uint256 _vestingCliff,
        uint256 _vestingPeriod,
        uint256 _enableBuyWithEth,
        uint256 _enableBuyWithUsdt
    ) external onlyOwner {
        require(_startTime > block.timestamp && _endTime > _startTime, "Invalid time");
        require(_price > 0, "Zero price");
        require(_tokensToSell > 0, "Zero tokens to sell");
        require(_baseDecimals > 0, "Zero decimals for the token");
        require(_vestingStartTime >= _endTime, "Vesting starts before Presale ends");

        presaleId++;

        presale[presaleId] = Presale(
            address(0),
            _startTime,
            _endTime,
            _price,
            _tokensToSell,
            _baseDecimals,
            _tokensToSell,
            _vestingStartTime,
            _vestingCliff,
            _vestingPeriod,
            _enableBuyWithEth,
            _enableBuyWithUsdt
        );

        emit PresaleCreated(presaleId, _tokensToSell, _startTime, _endTime, _enableBuyWithEth, _enableBuyWithUsdt);
    }

    function changeSaleTimes(uint256 _id, uint256 _startTime, uint256 _endTime) external checkPresaleId(_id) onlyOwner {
        require(_startTime > 0 || _endTime > 0, "Invalid parameters");
        if (_startTime > 0) {
            require(block.timestamp < presale[_id].startTime, "Sale already started");
            require(block.timestamp < _startTime, "Sale time in past");
            uint256 prevValue = presale[_id].startTime;
            presale[_id].startTime = _startTime;
            emit PresaleUpdated(bytes32("START"), prevValue, _startTime, block.timestamp);
        }

        if (_endTime > 0) {
            require(block.timestamp < presale[_id].endTime, "Sale already ended");
            require(_endTime > presale[_id].startTime, "Invalid endTime");
            uint256 prevValue = presale[_id].endTime;
            presale[_id].endTime = _endTime;
            emit PresaleUpdated(bytes32("END"), prevValue, _endTime, block.timestamp);
        }
    }

    function changeVestingStartTime(uint256 _id, uint256 _vestingStartTime) external checkPresaleId(_id) onlyOwner {
        require(_vestingStartTime >= presale[_id].endTime, "Vesting starts before Presale ends");
        uint256 prevValue = presale[_id].vestingStartTime;
        presale[_id].vestingStartTime = _vestingStartTime;
        emit PresaleUpdated(bytes32("VESTING_START_TIME"), prevValue, _vestingStartTime, block.timestamp);
    }

    function changeSaleTokenAddress(uint256 _id, address _newAddress) external checkPresaleId(_id) onlyOwner {
        require(_newAddress != address(0), "Zero token address");
        address prevValue = presale[_id].saleToken;
        presale[_id].saleToken = _newAddress;
        emit PresaleTokenAddressUpdated(prevValue, _newAddress, block.timestamp);
    }

    function changePrice(uint256 _id, uint256 _newPrice) external checkPresaleId(_id) onlyOwner {
        require(_newPrice > 0, "Zero price");
        require(presale[_id].startTime > block.timestamp, "Sale already started");
        uint256 prevValue = presale[_id].price;
        presale[_id].price = _newPrice;
        emit PresaleUpdated(bytes32("PRICE"), prevValue, _newPrice, block.timestamp);
    }

    function changeEnableBuyWithEth(uint256 _id, uint256 _enableToBuyWithEth) external checkPresaleId(_id) onlyOwner {
        uint256 prevValue = presale[_id].enableBuyWithEth;
        presale[_id].enableBuyWithEth = _enableToBuyWithEth;
        emit PresaleUpdated(bytes32("ENABLE_BUY_WITH_ETH"), prevValue, _enableToBuyWithEth, block.timestamp);
    }

    function changeEnableBuyWithUsdt(uint256 _id, uint256 _enableToBuyWithUsdt) external checkPresaleId(_id) onlyOwner {
        uint256 prevValue = presale[_id].enableBuyWithUsdt;
        presale[_id].enableBuyWithUsdt = _enableToBuyWithUsdt;
        emit PresaleUpdated(bytes32("ENABLE_BUY_WITH_USDT"), prevValue, _enableToBuyWithUsdt, block.timestamp);
    }

    function pausePresale(uint256 _id) external checkPresaleId(_id) onlyOwner {
        require(!paused[_id], "Already paused");
        paused[_id] = true;
        emit PresalePaused(_id, block.timestamp);
    }

    function unPausePresale(uint256 _id) external checkPresaleId(_id) onlyOwner {
        require(paused[_id], "Not paused");
        paused[_id] = false;
        emit PresaleUnpaused(_id, block.timestamp);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = aggregatorInterface.latestRoundData();
        price = (price * (10 ** 10));
        return uint256(price);
    }

    function buyWithUSDT(
        uint256 _id,
        uint256 amount
    ) external checkPresaleId(_id) checkSaleState(_id, amount) returns (bool) {
        require(!paused[_id], "Presale paused");
        require(presale[_id].enableBuyWithUsdt > 0, "Not allowed to buy with USDT");
        uint256 usdPrice = amount * presale[_id].price;
        usdPrice = usdPrice / (10 ** 12);
        presale[_id].inSale -= amount;

        Presale memory _presale = presale[_id];

        if (userVesting[_msgSender()][_id].totalAmount > 0) {
            userVesting[_msgSender()][_id].totalAmount += (amount * _presale.baseDecimals);
        } else {
            userVesting[_msgSender()][_id] = Vesting(
                (amount * _presale.baseDecimals),
                0,
                _presale.vestingStartTime + _presale.vestingCliff,
                _presale.vestingStartTime + _presale.vestingCliff + _presale.vestingPeriod
            );
        }

        uint256 ourAllowance = USDTInterface.allowance(_msgSender(), address(this));
        require(usdPrice <= ourAllowance, "Make sure to add enough allowance");
        (bool success, ) = address(USDTInterface).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), owner(), usdPrice)
        );
        require(success, "Token payment failed");
        emit TokensBought(_msgSender(), _id, address(USDTInterface), amount, usdPrice, block.timestamp);
        return true;
    }

    function buyWithEth(
        uint256 _id,
        uint256 amount
    ) external payable checkPresaleId(_id) checkSaleState(_id, amount) nonReentrant returns (bool) {
        require(!paused[_id], "Presale paused");
        require(presale[_id].enableBuyWithEth > 0, "Not allowed to buy with ETH");
        uint256 usdPrice = amount * presale[_id].price;
        uint256 ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        presale[_id].inSale -= amount;
        Presale memory _presale = presale[_id];

        if (userVesting[_msgSender()][_id].totalAmount > 0) {
            userVesting[_msgSender()][_id].totalAmount += (amount * _presale.baseDecimals);
        } else {
            userVesting[_msgSender()][_id] = Vesting(
                (amount * _presale.baseDecimals),
                0,
                _presale.vestingStartTime + _presale.vestingCliff,
                _presale.vestingStartTime + _presale.vestingCliff + _presale.vestingPeriod
            );
        }
        sendValue(payable(owner()), ethAmount);
        if (excess > 0) sendValue(payable(_msgSender()), excess);
        emit TokensBought(_msgSender(), _id, address(0), amount, ethAmount, block.timestamp);
        return true;
    }

    function ethBuyHelper(uint256 _id, uint256 amount) external view checkPresaleId(_id) returns (uint256 ethAmount) {
        uint256 usdPrice = amount * presale[_id].price;
        ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
    }

    function usdtBuyHelper(uint256 _id, uint256 amount) external view checkPresaleId(_id) returns (uint256 usdPrice) {
        usdPrice = amount * presale[_id].price;
        usdPrice = usdPrice / (10 ** 12);
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "ETH Payment failed");
    }

    function claimableAmount(address user, uint256 _id) public view checkPresaleId(_id) returns (uint256) {
        Vesting memory _user = userVesting[user][_id];
        require(_user.totalAmount > 0, "Nothing to claim");
        uint256 amount = _user.totalAmount - _user.claimedAmount;
        require(amount > 0, "Already claimed");

        if (block.timestamp < _user.claimStart) return 0;
        if (block.timestamp >= _user.claimEnd) return amount;

        uint256 noOfMonthsPassed = (block.timestamp - _user.claimStart) / MONTH;

        uint256 perMonthClaim = (_user.totalAmount * BASE_MULTIPLIER * MONTH) / (_user.claimEnd - _user.claimStart);

        uint256 amountToClaim = ((noOfMonthsPassed * perMonthClaim) / BASE_MULTIPLIER) - _user.claimedAmount;

        return amountToClaim;
    }

    function claim(address user, uint256 _id) public returns (bool) {
        uint256 amount = claimableAmount(user, _id);
        require(amount > 0, "Zero claim amount");
        require(presale[_id].saleToken != address(0), "Presale token address not set");
        require(amount <= IERC20(presale[_id].saleToken).balanceOf(address(this)), "Not enough tokens in the contract");
        userVesting[user][_id].claimedAmount += amount;
        bool status = IERC20(presale[_id].saleToken).transfer(user, amount);
        require(status, "Token transfer failed");
        emit TokensClaimed(user, _id, amount, block.timestamp);
        return true;
    }

    function claimMultiple(address[] calldata users, uint256 id) external returns (bool) {
        require(users.length > 0, "Zero users length");
        for (uint256 i; i < users.length; i++) {
            require(claim(users[i], id), "Claim failed");
        }
        return true;
    }
}
