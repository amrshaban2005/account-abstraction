// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {UserOperationLib} from "../lib/UserOperationLib.sol";

contract MockPaymaster {
    address public owner;
    address public entryPoint;
    address public sponsorSigner;

    event SponsorSignerUpdated(address indexed sponsorSigner);
    event UserOpSponsored(address indexed account, bytes32 indexed sponsorHash);

    error NotOwner();
    error NotEntryPoint();
    error InvalidSponsorSignature();

    constructor(address _entryPoint, address _sponsorSigner) {
        owner = msg.sender;
        entryPoint = _entryPoint;
        sponsorSigner = _sponsorSigner;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert NotEntryPoint();
        _;
    }

    function setSponsorSigner(address _sponsorSigner) external onlyOwner {
        sponsorSigner = _sponsorSigner;
        emit SponsorSignerUpdated(_sponsorSigner);
    }

    function getSponsorHash(UserOperationLib.PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                address(this),
                entryPoint,
                block.chainid,
                userOp.sender,
                userOp.nonce,
                keccak256(userOp.callData),
                userOpHash,
                maxCost
            )
        );
    }

    function validatePaymasterUserOp(
        UserOperationLib.PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external onlyEntryPoint returns (bytes memory context) {
        (, bytes memory sponsorSignature) = abi.decode(userOp.paymasterAndData, (address, bytes));

        bytes32 sponsorHash = getSponsorHash(userOp, userOpHash, maxCost);

        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(sponsorHash);

        address recoveredSigner = ECDSA.recover(ethSignedHash, sponsorSignature);

        if (recoveredSigner != sponsorSigner) {
            revert InvalidSponsorSignature();
        }

        emit UserOpSponsored(userOp.sender, sponsorHash);

        return abi.encode(userOp.sender);
    }
}
