// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UserOperationLib} from "./lib/UserOperationLib.sol";

contract SimpleAccount {
    address public owner;
    address public entryPoint;
    uint256 public nonce;

    event Executed(address indexed target, uint256 value, bytes data);
    event BatchExecuted(uint256 callsCount);
    event UserOpValidated(bytes32 indexed userOpHash, address recoveredSigner, uint256 nonce);

    error NotEntryPoint();
    error InvalidSignature();
    error InvalidNonce();
    error InvalidSender();
    error CallFailed();
    error InvalidBatchLength();

    constructor(address _owner, address _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
    }

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert NotEntryPoint();
        _;
    }

    function validateUserOp(UserOperationLib.PackedUserOperation calldata userOp, bytes32 userOpHash, uint256)
        external
        onlyEntryPoint
        returns (uint256 validationData)
    {
        if (userOp.sender != address(this)) {
            revert InvalidSender();
        }

        if (userOp.nonce != nonce) {
            revert InvalidNonce();
        }

        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        address recoveredSigner = ECDSA.recover(ethSignedHash, userOp.signature);

        if (recoveredSigner != owner) {
            revert InvalidSignature();
        }

        nonce++;

        emit UserOpValidated(userOpHash, recoveredSigner, userOp.nonce);

        return 0;
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyEntryPoint
        returns (bytes memory result)
    {
        (bool success, bytes memory returndata) = target.call{value: value}(data);

        if (!success) revert CallFailed();

        emit Executed(target, value, data);

        return returndata;
    }

    function executeBatch(address[] calldata targets, uint256[] calldata values, bytes[] calldata data)
        external
        onlyEntryPoint
        returns (bytes[] memory results)
    {
        if (targets.length != values.length || targets.length != data.length) {
            revert InvalidBatchLength();
        }

        results = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; i++) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(data[i]);

            if (!success) revert CallFailed();

            results[i] = returndata;
        }

        emit BatchExecuted(targets.length);
    }

    receive() external payable {}
}
