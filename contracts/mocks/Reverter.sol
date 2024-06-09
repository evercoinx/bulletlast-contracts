// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { IBulletLastPresale } from "../interfaces/IBulletLastPresale.sol";

contract Reverter {
    IBulletLastPresale public target;

    error TransferFailed();

    constructor(address target_) {
        target = IBulletLastPresale(target_);
    }

    receive() external payable {
        revert TransferFailed();
    }

    function buyWithEther(uint256 amount) external payable {
        target.buyWithEther{ value: msg.value }(amount);
    }
}
