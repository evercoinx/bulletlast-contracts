// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDTMock is ERC20 {
    constructor(address treasury, uint256 initialSupply) ERC20("Tether USD", "USDT") {
        _mint(treasury, initialSupply);
    }
}
