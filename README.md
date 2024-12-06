Qubic Token Bridge
==================

The `QubicToken` is an ERC20 smart contract designed to be a representation of the native Qubic token on EVM compatible networks. The minting and burning of WQUBIC tokens is controlled by the `QubicBridge` contract.

The `QubicBridge` is an Ethereum smart contract designed to deposit and withdraw WQUBIC tokens on EVM-compatible networks. It is part of the Qubic-Ethereum Bridge, where bridge operation is coordinated by a middleware backend. It emits standard events that the backend middleware listens and reacts to.

Design considerations
--------------------

The initial smart contracts have been implemented with a focus on simplicity and gas efficiency. Future enhancements will include:
- Upgradeable proxy contracts
- Multi-signature consensus mechanism

Roles
-----

- `QubicToken`
  - `Admin`:
    - Can add and remove minters, as well as change the admin.
    - Only one admin is allowed.
  - `Operator`:
    - Can mint and burn WQUBIC tokens.
    - Multiple operators are allowed.
    - Any bridge contract in operation must be added as an operator.

- `QubicBridge`
  - `Admin`:
    - Can add and remove managers.
    - Can change the admin.
    - Only one admin is allowed.
  - `Manager`:
    - Can add and remove operators.
    - Multiple managers are allowed.
  - `Operator`:
    - Can operate the bridge to push and pull tokens.
    - Multiple operators are allowed.
    - Any backend node in operation must be added as an operator.

Transfer Fees
-------------

The Qubic Token Bridge implements a transfer fee mechanism to cover operational costs and incentivize operators.

**Base transfer fee**: The base fee is configured by the Admin and is expressed in basis points (1 basis point = 0.01%).

**Operator fee percentage**: For each token transfer transaction (execute, confirm, revert), the operator can opt to receive the full fee or a part of it, allowing for fair compensation for their role in the transaction. It is expressed as a percentage of the base fee (no decimal places).

The final fee is deducted from the transfer amount as follows:

```
transfer_fee = transfer_amount * base_fee/10000 * operator_fee/100 (rounded up)
final_amount = transfer_amount - transfer_fee
```

The deducted fee is transferred to the recipient designated by the operator for that transaction, allowing for separate storage of funds.

Requirements
------------
- [Foundry](https://book.getfoundry.sh/)

How to test
----------

```bash
forge install
forge test
```

How to deploy
----------

```bash
forge script script/deploy.s.sol --broadcast --rpc-url <RPC_URL> --account <KEYSTORE_ACCOUNT>
```

Operation of the Qubic Token Bridge
==============================================================

The Qubic Token Bridge securely facilitates the transfer of native **QUBIC** tokens between the **Qubic** and **Ethereum** blockchains. It utilizes smart contracts and a middleware backend to validate and coordinate operations, ensuring smooth and secure transactions across both networks.

Bridge Mechanism
----------------

This bridge employs a classical **lock and mint** mechanism, with a main smart contract on Qubic and another one on Ethereum, to guarantee token equivalence and security:

*   **From Qubic to Ethereum**: **QUBIC** tokens are **locked** on the Qubic network, and equivalent **WQUBIC** tokens are **minted** on Ethereum.

*   **From Ethereum to Qubic**: **WQUBIC** tokens are **burned** on Ethereum, and equivalent **QUBIC** tokens are **released** on the Qubic network.

System Components
-----------------

*   **Bridge Contract on Qubic**: Initiates transfers by taking the tokens from the user's wallet and retaining them until the transfer is confirmed, after which they are moved to the lock contract. It emits transfer events to inform the backend and frontend about the transaction status. Also receives transfers from the Ethereum bridge contract.

*   **Lock Contract on Qubic**: Stores the **QUBIC** tokens locked by the bridge. Each token locked in this contract must be backed by an equivalent token minted on Ethereum.

*   **Bridge Contract on Ethereum**: Mints and burns **WQUBIC** tokens based on instructions received from the backend. Each token minted on Ethereum must be backed by a token locked in the Qubic lock contract. Also initiates transfers to the Qubic bridge contract.

*   **Middleware Backend**: Acts as an intermediate coordinator, ensuring proper execution of transactions between both chains. From the perspective of the bridge, tokens are **pulled** from one blockchain and **pushed** to the other. It also holds the required keys to operate the bridge contracts.

*   **Tokens**:

    *   **QUBIC**: The Qubic network's native token.

    *   **WQUBIC**: The Ethereum ERC20 token representing **QUBIC**.



Transfer Process
----------------

### 1\. Transfer from Qubic to Ethereum

1.  **Initiation**: The user calls the bridge contract on Qubic via the frontend, specifying the amount to transfer and the destination wallet address on Ethereum.

2.  **Pulling**: The bridge contract verifies the information, takes the user's **QUBIC** tokens, and emits a tokens pulled event. The tokens are retained in the contract until the push on Ethereum is confirmed.

3.  **Pull Coordination**: The **backend** captures the tokens pulled event, verifies the information, and calls the bridge contract on Ethereum, specifying the number of tokens to push and the destination wallet.

4.  **Pushing**: The bridge contract on Ethereum verifies the information and mints **WQUBIC** tokens in the destination wallet. A tokens pushed event is emitted to confirm the operation.

5.  **Push Coordination**: The **backend** captures the tokens pushed event and confirms to the bridge contract on Qubic that the push was successful.

6.  **Completion**: The bridge contract on Qubic transfers the retained **QUBIC** tokens to the lock contract and emits a transfer completion event.

7.  **User Notification**: The frontend captures the transfer completion event and displays a confirmation of the operation to the user.


### 2\. Transfer from Ethereum to Qubic

1.  **Initiation**: The user calls the bridge contract on Ethereum via the frontend, specifying the amount of **WQUBIC** tokens to transfer and the destination wallet address on Qubic.

2.  **Pulling**: The bridge contract on Ethereum verifies the information and takes the user's **WQUBIC** tokens, emitting a tokens pulled event. The tokens are retained until the push on Qubic is confirmed.

3.  **Pull Coordination**: The **backend** captures the tokens pulled event, verifies the information, and calls the bridge contract on Qubic, specifying the number of tokens to push and the destination wallet.

4.  **Pushing**: The bridge contract on Qubic verifies the information and transfers the **QUBIC** tokens from the lock contract to the destination wallet, emitting a tokens pushed event.

5.  **Push Coordination**: The **backend** captures the tokens pushed event and confirms to the bridge contract on Ethereum that the push was successful.

6.  **Completion**: The bridge contract on Ethereum burns the retained tokens and emits a transfer completion event.

7.  **User Notification**: The frontend captures the transfer completion event and displays a confirmation of the operation to the user.
