# Account Abstraction Simulation

A small Foundry project that demonstrates the core ideas behind ERC-4337 account abstraction without requiring a bundler or the production EntryPoint contract.

The simulation builds a `PackedUserOperation`, signs it with the smart-account owner, optionally sponsors it with a paymaster, deploys the account counterfactually with `CREATE2`, validates the operation, charges a mock gas cost, and executes a call through the smart account.

## What it demonstrates

- Smart contract accounts controlled by an ECDSA owner
- User-operation hashing and signature validation
- Nonce validation and replay protection
- Counterfactual account addresses and `CREATE2` deployment
- EntryPoint-only account execution
- Paymaster authorization and sponsored mock gas
- Single and batched calls from a smart account

## Architecture

| Component | Purpose |
| --- | --- |
| `SimpleAccount` | Validates the owner's signature and nonce, then executes calls requested by the EntryPoint. |
| `SimpleAccountFactory` | Predicts and deploys deterministic account addresses using `CREATE2`. |
| `MockEntryPoint` | Coordinates deployment, validation, mock gas charging, and execution. |
| `MockPaymaster` | Verifies a sponsor signature and pays the operation's mock gas cost. |
| `UserOperationLib` | Defines the simulated user operation and its domain-bound hash. |
| `Counter` | Example target contract called through the smart account. |

## Simulated user-operation flow

1. The client predicts the smart-account address through `SimpleAccountFactory.getAddress`.
2. It encodes an account call such as `SimpleAccount.execute(counter, 0, setNumber(1234))`.
3. It includes factory initialization data so the EntryPoint can deploy the account if it does not exist.
4. The account owner signs the user-operation hash.
5. When sponsorship is enabled, the sponsor also signs the paymaster authorization hash.
6. `MockEntryPoint.handleOp` deploys the account, validates the owner signature and nonce, validates the paymaster, deducts the fixed mock gas cost, and executes the call.
7. The test verifies that the account was deployed, the counter changed, the nonce incremented, and the paymaster deposit was charged.

```text
Owner + Sponsor
      |
      | signatures
      v
PackedUserOperation ---> MockEntryPoint
                            |  deploy via CREATE2
                            v
                    SimpleAccountFactory
                            |
                            v
                      SimpleAccount
                       |          |
                validate op   execute call
                                  |
                                  v
                               Counter

MockPaymaster <--- sponsorship validation and mock gas charge
```

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git, including submodule support

## Setup

```bash
git clone --recurse-submodules <repository-url>
cd account-abstraction
forge build
```

If the repository was cloned without submodules:

```bash
git submodule update --init --recursive
```

## Run the simulation

Run all tests:

```bash
forge test
```

Run the complete user-operation flow with detailed traces:

```bash
forge test --match-test testUserOperationUpdatesCounter -vvvv
```

The main test covers this end-to-end scenario:

- fund the paymaster's EntryPoint deposit;
- predict an undeployed account address;
- prepare a call that changes `Counter.number` to `1234`;
- sign the operation as the account owner;
- authorize sponsorship with the sponsor signer;
- submit the operation to `MockEntryPoint`; and
- assert deployment, execution, nonce advancement, and gas payment.

## Local deployment

Start Anvil:

```bash
anvil
```

In another terminal, choose one of Anvil's private keys and derive the corresponding sponsor address:

```bash
export PRIVATE_KEY=<anvil-private-key>
export SPONSOR_SIGNER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY")
```

Deploy the mock EntryPoint, factory, paymaster, and two counters:

```bash
forge script script/DeployStep.s.sol:DeployStep \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$PRIVATE_KEY" \
  --broadcast
```

The script prints the deployed contract addresses. A complete off-chain submission client is outside this simulation; the Foundry test constructs and submits the user operation directly.

## Important simplifications

Compared with production ERC-4337, this project deliberately omits or simplifies several parts:

- no bundler or alternative mempool;
- no canonical EntryPoint deployment or interfaces;
- no full validation-data, prefund, gas-metering, or post-operation lifecycle;
- a fixed `0.0001 ether` mock gas charge;
- simplified `initCode` and `paymasterAndData` encoding; and
- no production hardening, audits, or adversarial security guarantees.

For the production protocol and current interfaces, refer to the [ERC-4337 specification](https://eips.ethereum.org/EIPS/eip-4337).

## Useful Foundry commands

```bash
forge build       # Compile contracts
forge test        # Run tests
forge fmt         # Format Solidity files
forge snapshot    # Generate gas snapshots
```

## License

MIT
