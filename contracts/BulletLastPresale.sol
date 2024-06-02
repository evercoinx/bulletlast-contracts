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

    uint256 public presaleId;
    AggregatorV3Interface public priceFeed;
    IERC20 public usdt;

    mapping(uint256 presaleId => bool paused) public paused;
    mapping(uint256 presaleId => Presale presale) public presale;
    mapping(address user => mapping(uint256 presaleId => Vesting vesting)) public userVesting;

    modifier checkPresaleId(uint256 id) {
        require(id > 0 && id <= presaleId, "Invalid presale id");
        _;
    }

    modifier checkSaleState(uint256 id, uint256 amount) {
        require(
            block.timestamp >= presale[id].startTime && block.timestamp <= presale[id].endTime,
            "Invalid time for buying"
        );
        require(amount > 0 && amount <= presale[id].inSale, "Invalid sale amount");
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

    function createPresale(
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

        presaleId++;

        presale[presaleId] = Presale({
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

        emit PresaleCreated(presaleId, tokensToSell, startTime, endTime, enableBuyWithEther, enableBuyWithUSDT);
    }

    function changeSaleTimes(uint256 id, uint256 startTime, uint256 endTime) external onlyOwner checkPresaleId(id) {
        require(startTime > 0 || endTime > 0, "Invalid parameters");
        if (startTime > 0) {
            require(block.timestamp < presale[id].startTime, "Sale already started");
            require(block.timestamp < startTime, "Sale time in past");
            uint256 prevValue = presale[id].startTime;
            presale[id].startTime = startTime;
            emit PresaleUpdated(bytes32("START"), prevValue, startTime, block.timestamp);
        }

        if (endTime > 0) {
            require(block.timestamp < presale[id].endTime, "Sale already ended");
            require(endTime > presale[id].startTime, "Invalid endTime");
            uint256 prevValue = presale[id].endTime;
            presale[id].endTime = endTime;
            emit PresaleUpdated(bytes32("END"), prevValue, endTime, block.timestamp);
        }
    }

    function changeVestingStartTime(uint256 id, uint256 vestingStartTime) external onlyOwner checkPresaleId(id) {
        require(vestingStartTime >= presale[id].endTime, "Unexpected vesting start");
        uint256 prevValue = presale[id].vestingStartTime;
        presale[id].vestingStartTime = vestingStartTime;
        emit PresaleUpdated(bytes32("VESTING_START_TIME"), prevValue, vestingStartTime, block.timestamp);
    }

    function changeSaleTokenAddress(uint256 id, address _newAddress) external onlyOwner checkPresaleId(id) {
        require(_newAddress != address(0), "Zero token address");
        address prevValue = presale[id].saleToken;
        presale[id].saleToken = _newAddress;
        emit PresaleTokenAddressUpdated(prevValue, _newAddress, block.timestamp);
    }

    function changePrice(uint256 id, uint256 _newPrice) external onlyOwner checkPresaleId(id) {
        require(_newPrice > 0, "Zero price");
        require(presale[id].startTime > block.timestamp, "Sale already started");
        uint256 prevValue = presale[id].price;
        presale[id].price = _newPrice;
        emit PresaleUpdated(bytes32("PRICE"), prevValue, _newPrice, block.timestamp);
    }

    function changeEnableBuyWithEther(uint256 id, uint256 enableToBuyWithEther) external onlyOwner checkPresaleId(id) {
        uint256 prevValue = presale[id].enableBuyWithEther;
        presale[id].enableBuyWithEther = enableToBuyWithEther;
        emit PresaleUpdated(bytes32("ENABLE_BUY_WITH_ETH"), prevValue, enableToBuyWithEther, block.timestamp);
    }

    function changeEnableBuyWithUSDT(uint256 id, uint256 enableToBuyWithUSDT) external onlyOwner checkPresaleId(id) {
        uint256 prevValue = presale[id].enableBuyWithUSDT;
        presale[id].enableBuyWithUSDT = enableToBuyWithUSDT;
        emit PresaleUpdated(bytes32("ENABLE_BUY_WITH_USDT"), prevValue, enableToBuyWithUSDT, block.timestamp);
    }

    function pausePresale(uint256 id) external onlyOwner checkPresaleId(id) {
        require(!paused[id], "Already paused");
        paused[id] = true;
        emit PresalePaused(id, block.timestamp);
    }

    function unpausePresale(uint256 id) external onlyOwner checkPresaleId(id) {
        require(paused[id], "Not paused");
        paused[id] = false;
        emit PresaleUnpaused(id, block.timestamp);
    }

    function buyWithEther(
        uint256 id,
        uint256 amount
    ) external payable checkPresaleId(id) checkSaleState(id, amount) nonReentrant returns (bool) {
        require(!paused[id], "Presale paused");
        require(presale[id].enableBuyWithEther > 0, "Not allowed to buy with ETH");
        uint256 usdPrice = amount * presale[id].price;
        uint256 ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
        require(msg.value >= ethAmount, "Less payment");
        uint256 excess = msg.value - ethAmount;
        presale[id].inSale -= amount;
        Presale memory _presale = presale[id];

        if (userVesting[_msgSender()][id].totalAmount > 0) {
            userVesting[_msgSender()][id].totalAmount += (amount * _presale.baseDecimals);
        } else {
            userVesting[_msgSender()][id] = Vesting(
                (amount * _presale.baseDecimals),
                0,
                _presale.vestingStartTime + _presale.vestingCliff,
                _presale.vestingStartTime + _presale.vestingCliff + _presale.vestingPeriod
            );
        }

        _sendValue(payable(owner()), ethAmount);

        if (excess > 0) {
            _sendValue(payable(_msgSender()), excess);
        }
        emit TokensBought(_msgSender(), id, address(0), amount, ethAmount, block.timestamp);
        return true;
    }

    function buyWithUSDT(
        uint256 id,
        uint256 amount
    ) external checkPresaleId(id) checkSaleState(id, amount) returns (bool) {
        require(!paused[id], "Presale paused");
        require(presale[id].enableBuyWithUSDT > 0, "Not allowed to buy with USDT");
        uint256 usdPrice = amount * presale[id].price;
        usdPrice = usdPrice / (10 ** 12);
        presale[id].inSale -= amount;

        Presale memory _presale = presale[id];

        if (userVesting[_msgSender()][id].totalAmount > 0) {
            userVesting[_msgSender()][id].totalAmount += (amount * _presale.baseDecimals);
        } else {
            userVesting[_msgSender()][id] = Vesting(
                (amount * _presale.baseDecimals),
                0,
                _presale.vestingStartTime + _presale.vestingCliff,
                _presale.vestingStartTime + _presale.vestingCliff + _presale.vestingPeriod
            );
        }

        uint256 ourAllowance = usdt.allowance(_msgSender(), address(this));
        require(usdPrice <= ourAllowance, "Insufficient USDT allowance");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(usdt).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", _msgSender(), owner(), usdPrice)
        );
        require(success, "Token payment failed");

        emit TokensBought(_msgSender(), id, address(usdt), amount, usdPrice, block.timestamp);
        return true;
    }

    function claimMultiple(address[] calldata users, uint256 id) external returns (bool) {
        require(users.length > 0, "Zero users length");
        for (uint256 i; i < users.length; i++) {
            require(claim(users[i], id), "Claim failed");
        }
        return true;
    }

    function etherBuyHelper(uint256 id, uint256 amount) external view checkPresaleId(id) returns (uint256 ethAmount) {
        uint256 usdPrice = amount * presale[id].price;
        ethAmount = (usdPrice * BASE_MULTIPLIER) / getLatestPrice();
    }

    function usdtBuyHelper(uint256 id, uint256 amount) external view checkPresaleId(id) returns (uint256 usdPrice) {
        usdPrice = amount * presale[id].price;
        usdPrice = usdPrice / (10 ** 12);
    }

    function claim(address user, uint256 id) public returns (bool) {
        uint256 amount = claimableAmount(user, id);
        require(amount > 0, "Zero claim amount");
        require(presale[id].saleToken != address(0), "Presale token address not set");
        require(amount <= IERC20(presale[id].saleToken).balanceOf(address(this)), "Not enough tokens in contract");
        userVesting[user][id].claimedAmount += amount;
        bool status = IERC20(presale[id].saleToken).transfer(user, amount);
        require(status, "Token transfer failed");
        emit TokensClaimed(user, id, amount, block.timestamp);
        return true;
    }

    function claimableAmount(address user, uint256 id) public view checkPresaleId(id) returns (uint256) {
        Vesting memory _user = userVesting[user][id];
        require(_user.totalAmount > 0, "Nothing to claim");
        uint256 amount = _user.totalAmount - _user.claimedAmount;
        require(amount > 0, "Already claimed");

        if (block.timestamp < _user.claimStart) {
            return 0;
        }
        if (block.timestamp >= _user.claimEnd) {
            return amount;
        }

        uint256 noOfMonthsPassed = (block.timestamp - _user.claimStart) / MONTH;
        uint256 perMonthClaim = (_user.totalAmount * BASE_MULTIPLIER * MONTH) / (_user.claimEnd - _user.claimStart);
        uint256 amountToClaim = ((noOfMonthsPassed * perMonthClaim) / BASE_MULTIPLIER) - _user.claimedAmount;

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
