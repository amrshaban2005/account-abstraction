// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Counter {
    uint256 public number;

    event NumberChanged(address indexed caller, uint256 newNumber);

    function setNumber(uint256 newNumber) external {
        number = newNumber;
        emit NumberChanged(msg.sender, newNumber);
    }
}
