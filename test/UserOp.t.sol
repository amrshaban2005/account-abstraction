// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {SimpleAccount} from "../src/SimpleAccount.sol";
import {MockEntryPoint} from "../src/mock/MockEntryPoint.sol";
import {MockPaymaster} from "../src/mock/MockPaymaster.sol";
import {UserOperationLib} from "../src/lib/UserOperationLib.sol";
import {SimpleAccountFactory} from "../src/SimpleAccountFactory.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract UserOpTest is Test {
    MockEntryPoint entryPoint;
    MockPaymaster paymaster;
    SimpleAccount account;
    Counter counter;
    SimpleAccountFactory factory;

    uint256 ownerPrivateKey = 0xA11CE;
    address owner;

    uint256 sponsorPrivateKey = 0xB0B;
    address sponsorSigner;

    function setUp() public {
        owner = vm.addr(ownerPrivateKey);
        sponsorSigner = vm.addr(sponsorPrivateKey);

        entryPoint = new MockEntryPoint();
        factory = new SimpleAccountFactory(address(entryPoint));
        paymaster = new MockPaymaster(address(entryPoint), sponsorSigner);
        account = new SimpleAccount(owner, address(entryPoint));
        counter = new Counter();
    }

    function testUserOperationUpdatesCounter() public {
        entryPoint.depositTo{value: 1 ether}(address(paymaster));

        address predictedAccount = factory.getAddress(owner, 123);
        // Confirm account does not exist yet
        assertEq(predictedAccount.code.length, 0);

        bytes memory targetData = abi.encodeWithSignature("setNumber(uint256)", 1234);

        bytes memory accountCallData =
            abi.encodeWithSignature("execute(address,uint256,bytes)", address(counter), 0, targetData);

        // Factory calldata: createAccount(owner, salt)
        bytes memory factoryCallData = abi.encodeWithSignature("createAccount(address,uint256)", owner, 123);

        UserOperationLib.PackedUserOperation memory op;

        op.sender = predictedAccount;
        op.nonce = account.nonce();
        op.initCode = abi.encode(address(factory), factoryCallData);
        op.callData = accountCallData;
        op.callGasLimit = 100000;
        op.verificationGasLimit = 100000;
        op.preVerificationGas = 21000;
        op.maxFeePerGas = 1 gwei;
        op.maxPriorityFeePerGas = 1 gwei;

        bytes32 userOpHash = UserOperationLib.hashMemory(op, address(entryPoint), block.chainid);

        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, ethSignedHash);

        op.signature = abi.encodePacked(r, s, v);

        bytes32 sponsorHash = paymaster.getSponsorHash(op, userOpHash, entryPoint.MOCK_GAS_COST());

        bytes32 ethSignedSponsorHash = MessageHashUtils.toEthSignedMessageHash(sponsorHash);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(sponsorPrivateKey, ethSignedSponsorHash);

        //bytes memory sponsorSignature = abi.encodePacked(r2, s2, v2);
        op.paymasterAndData = abi.encode(address(paymaster), abi.encodePacked(r2, s2, v2));

        entryPoint.handleOp(op);
        assertGt(predictedAccount.code.length, 0);
        assertEq(counter.number(), 1234);
        assertEq(SimpleAccount(payable(predictedAccount)).nonce(), 1);
        assertEq(entryPoint.deposits(address(paymaster)), 1 ether - entryPoint.MOCK_GAS_COST());
    }
}
