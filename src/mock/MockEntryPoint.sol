// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UserOperationLib} from "../lib/UserOperationLib.sol";

interface IAccountLike {
    function validateUserOp(
        UserOperationLib.PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

interface IPaymasterLike {
    function validatePaymasterUserOp(
        UserOperationLib.PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context);
}

contract MockEntryPoint {
    mapping(address => uint256) public deposits;

    uint256 public constant MOCK_GAS_COST = 0.0001 ether;

    event Deposited(address indexed account, uint256 amount);

    event GasCharged(address indexed payer, uint256 amount);

    event AccountDeployed(address indexed account, address indexed factory);

    event UserOpHandled(address indexed sender, uint256 indexed nonce, bytes callData, bytes signature);

    function depositTo(address account) external payable {
        deposits[account] += msg.value;

        emit Deposited(account, msg.value);
    }

    function getUserOpHash(UserOperationLib.PackedUserOperation memory userOp) public view returns (bytes32) {
        return UserOperationLib.hashMemory(userOp, address(this), block.chainid);
    }

    function handleOp(UserOperationLib.PackedUserOperation calldata userOp) external {
        bytes32 userOpHash = UserOperationLib.hash(userOp, address(this), block.chainid);

        // 1. If smart account is not deployed, deploy it using initCode
        if (userOp.sender.code.length == 0) {
            require(userOp.initCode.length > 0, "Account not deployed and no initCode");

            (address factory, bytes memory factoryCallData) = abi.decode(userOp.initCode, (address, bytes));

            (bool deployed,) = factory.call(factoryCallData);
            require(deployed, "Factory deployment failed");

            require(userOp.sender.code.length > 0, "Account still not deployed");

            emit AccountDeployed(userOp.sender, factory);
        }

        // 2. Validate smart account signature / nonce
        IAccountLike(userOp.sender).validateUserOp(userOp, userOpHash, 0);

        // 3. Decide who pays gas: smart account or paymaster
        address payer = userOp.sender;

        if (userOp.paymasterAndData.length > 0) {
            (address paymaster,) = abi.decode(userOp.paymasterAndData, (address, bytes));

            IPaymasterLike(paymaster).validatePaymasterUserOp(userOp, userOpHash, MOCK_GAS_COST);

            payer = paymaster;
        }

        // 4. Charge mock gas cost
        require(deposits[payer] >= MOCK_GAS_COST, "Insufficient deposit");

        deposits[payer] -= MOCK_GAS_COST;

        // 5. Execute smart account calldata
        (bool success,) = userOp.sender.call(userOp.callData);
        require(success, "AA call failed");

        emit GasCharged(payer, MOCK_GAS_COST);

        emit UserOpHandled(userOp.sender, userOp.nonce, userOp.callData, userOp.signature);
    }
}
