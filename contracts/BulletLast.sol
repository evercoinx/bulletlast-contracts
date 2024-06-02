// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BulletLast ERC20 Token Contract
/// @notice This contract creates the Bullet Last (LEAD) token with specific allocations and lock periods.
/// @dev This contract uses OpenZeppelin's ERC20 and Ownable implementations.
contract BulletLast is ERC20, Ownable {
    /// @notice Address of wallet1 (owner) for presale and liquidity
    address private constant wallet1 = 0x3951B3a254A4285683aBc08E63B2e632A4aa3752;

    /// @notice Address of wallet2 for marketing purposes
    address private constant wallet2 = 0xBAb234Fc133a3f09f42318901D28eb683B6A5A2c;

    /// @notice Address of wallet3 for partners and advisors
    address private constant wallet3 = 0x4C4922efF81AE8A1C8270EEA008cdC9095e9276a;

    /// @notice Total supply of the token
    uint256 private constant _initialSupply = 1_000_000_000 * 10 ** 18;

    /// @notice Allocation for wallet1 (owner)
    uint256 private constant _wallet1Amount = 380_000_000 * 10 ** 18;

    /// @notice Allocation for wallet2 (marketing)
    uint256 private constant _wallet2Amount = 70_000_000 * 10 ** 18;

    /// @notice Allocation for wallet3 (partners & advisors)
    uint256 private constant _wallet3Amount = 50_000_000 * 10 ** 18;

    /// @notice Total amount of tokens locked
    uint256 private constant _lockAmount = 500_000_000 * 10 ** 18;

    /// @notice Amount of tokens locked for 6 months
    uint256 private constant _lock6MonthsAmount = 50_000_000 * 10 ** 18;

    /// @notice Amount of tokens locked for 12 months
    uint256 private constant _lock12MonthsAmount = 250_000_000 * 10 ** 18;

    /// @notice Amount of tokens locked for 24 months
    uint256 private constant _lock24MonthsAmount = 200_000_000 * 10 ** 18;

    uint256 private _unlockTimestamp6Months;
    uint256 private _unlockTimestamp12Months;
    uint256 private _unlockTimestamp24Months;

    /// @notice Constructor to initialize the token with the specified allocations and lock periods.
    /// @param initialOwner Address of the initial owner (usually wallet1)
    constructor(address initialOwner) ERC20("Bullet Last", "LEAD") Ownable(initialOwner) {
        _mint(wallet1, _wallet1Amount);
        _mint(wallet2, _wallet2Amount);
        _mint(wallet3, _wallet3Amount);
        _mint(address(this), _lockAmount);

        _unlockTimestamp6Months = block.timestamp + 6 * 30 days;
        _unlockTimestamp12Months = block.timestamp + 12 * 30 days;
        _unlockTimestamp24Months = block.timestamp + 24 * 30 days;
    }

    /// @notice Override transfer function to enforce lock periods for non-owner transfers.
    /// @param recipient Address to receive the tokens
    /// @param amount Amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (_msgSender() != owner()) {
            require(block.timestamp >= _unlockTimestamp24Months, "Tokens are still locked");
        }
        return super.transfer(recipient, amount);
    }

    /// @notice Function to unlock tokens based on the lock periods.
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
