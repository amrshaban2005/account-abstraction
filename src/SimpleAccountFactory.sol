// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SimpleAccount} from "./SimpleAccount.sol";

contract SimpleAccountFactory {
    address public immutable entryPoint;

    event AccountCreated(address indexed account, address indexed owner, uint256 indexed salt);

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    function createAccount(address owner, uint256 salt) external returns (address account) {
        account = this.getAddress(owner, salt);

        if (account.code.length > 0) {
            return account;
        }

        bytes memory bytecode = abi.encodePacked(type(SimpleAccount).creationCode, abi.encode(owner, entryPoint));

        bytes32 finalSalt = bytes32(salt);

        assembly {
            account := create2(0, add(bytecode, 0x20), mload(bytecode), finalSalt)

            if iszero(account) {
                revert(0, 0)
            }
        }

        emit AccountCreated(account, owner, salt);
    }

    function getAddress(address owner, uint256 salt) external view returns (address predicted) {
        bytes memory bytecode = abi.encodePacked(type(SimpleAccount).creationCode, abi.encode(owner, entryPoint));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(salt), keccak256(bytecode)));

        predicted = address(uint160(uint256(hash)));
    }
}
