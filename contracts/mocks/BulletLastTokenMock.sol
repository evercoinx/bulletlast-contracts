// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract BulletLastTokenMock is ERC20, Ownable {
    address private constant wallet1 = 0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7;

    address private constant wallet2 = 0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7;

    address private constant wallet3 = 0x58Dd2a0F95E346b9b891E0ad23E55B892EE803d7;

    uint256 private constant _initialSupply = 1_000_000_000 * 10 ** 18;

    uint256 private constant _wallet1Amount = 380_000_000 * 10 ** 18;

    uint256 private constant _wallet2Amount = 70_000_000 * 10 ** 18;

    uint256 private constant _wallet3Amount = 50_000_000 * 10 ** 18;

    uint256 private constant _lockAmount = 500_000_000 * 10 ** 18;

    uint256 private constant _lock6MonthsAmount = 50_000_000 * 10 ** 18;

    uint256 private constant _lock12MonthsAmount = 250_000_000 * 10 ** 18;

    uint256 private constant _lock24MonthsAmount = 200_000_000 * 10 ** 18;

    uint256 private _unlockTimestamp6Months;
    uint256 private _unlockTimestamp12Months;
    uint256 private _unlockTimestamp24Months;

    constructor(address initialOwner) ERC20("Bullet Last", "LEAD") Ownable(initialOwner) {
        _mint(wallet1, _wallet1Amount);
        _mint(wallet2, _wallet2Amount);
        _mint(wallet3, _wallet3Amount);
        _mint(address(this), _lockAmount);

        _unlockTimestamp6Months = block.timestamp + 6 * 30 days;
        _unlockTimestamp12Months = block.timestamp + 12 * 30 days;
        _unlockTimestamp24Months = block.timestamp + 24 * 30 days;
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (_msgSender() != owner()) {
            require(block.timestamp >= _unlockTimestamp24Months, "Tokens are still locked");
        }
        return super.transfer(recipient, amount);
    }

    function unlockTokens() public onlyOwner {
        if (block.timestamp >= _unlockTimestamp24Months) {
            _transfer(address(this), owner(), _lock24MonthsAmount);
        } else if (block.timestamp >= _unlockTimestamp12Months) {
            _transfer(address(this), owner(), _lock12MonthsAmount);
        } else if (block.timestamp >= _unlockTimestamp6Months) {
            _transfer(address(this), owner(), _lock6MonthsAmount);
        } else {
            revert("Tokens are still locked");
        }
    }
}
