// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDTTokenMock is Ownable, ERC20 {
    constructor(address treasury, uint256 initialSupply) ERC20("Tether USD", "USDT") Ownable(_msgSender()) {
        _mint(treasury, initialSupply);
    }
}
