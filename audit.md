# Qubic - Vottun Bridge: Security Audit Report

**Preliminary Comments** | CertiK | Assessed on Feb 18th, 2026

---

## Executive Summary

| Field | Details |
|-------|---------|
| **Type** | Bridge |
| **Language** | C++, Solidity |
| **Ecosystem** | Qubic |
| **Methods** | Manual Review, Static Analysis |
| **Timeline** | Preliminary comments published on 02/18/2026 |

---

## Vulnerability Summary

| Total Findings | Resolved | Multi-Sig | Partially Resolved | Acknowledged | Declined | Pending |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **24** | 9 | 1 | 0 | 2 | 0 | 12 |

### By Severity

| Severity | Count | Status | Description |
|----------|:-----:|--------|-------------|
| **Centralization** | 3 | 1 Multi-Sig, 1 Resolved, 1 Acknowledged | Privileged roles & functions and their capabilities, or instances where the project takes custody of users' assets. |
| **Critical** | 0 | - | Impact the safe functioning of a platform and must be addressed before launch. |
| **Major** | 1 | 1 Pending | Logical errors that, under specific circumstances, could result in fund losses or loss of project control. |
| **Medium** | 4 | 4 Pending | May not pose a direct risk to users' funds, but can affect the overall functioning of a platform. |
| **Minor** | 13 | 5 Resolved, 1 Acknowledged, 7 Pending | Same as above but on a smaller scale. Generally do not compromise overall integrity. |
| **Informational** | 3 | 3 Resolved | Recommendations to improve code style or operations to fall within industry best practices. |
| **Discussion** | 0 | - | Impact yet to be determined, requires further clarification from the project team. |

---

## Codebase & Audit Scope

### Repositories

| Repository | Commit |
|------------|--------|
| [sergimima/core-1](https://github.com/sergimima/core-1/blob/9b3521ce1c3078123b73cb028227495e0e8df5d0/src/contracts/VottunBridge.h) | `9b3521ce1c3078123b73cb028227495e0e8df5d0` |
| [vottundev/vottun-qubic-bridge-sc-evm](https://github.com/vottundev/vottun-qubic-bridge-sc-evm/tree/ca18ed4dc7cd00b31c347949ab50e3dec1191189/src) | `ca18ed4dc7cd00b31c347949ab50e3dec1191189` |

### Files In Scope

| Repository | Files |
|------------|-------|
| vottundev/vottun-qubic-bridge-sc-evm | `QubicBridge.sol`, `QubicToken.sol` |
| sergimima/core-1 | `VottunBridge.h` |

---

## Approach & Methods

This audit was conducted for Qubic to evaluate the security and correctness of the smart contracts associated with the Qubic-Vottun Bridge project. The assessment included a comprehensive review of the in-scope smart contracts using a combination of **Manual Review** and **Static Analysis**.

The review process emphasized the following areas:

- Architecture review and threat modeling to understand systemic risks and identify design-level flaws.
- Identification of vulnerabilities through both common and edge-case attack vectors.
- Manual verification of contract logic to ensure alignment with intended design and business requirements.
- Dynamic testing to validate runtime behavior and assess execution risks.
- Assessment of code quality and maintainability, including adherence to current best practices and industry standards.

### General Recommendations

- Improve code readability and maintainability by adopting a clean architectural pattern and modular design.
- Strengthen testing coverage, including unit and integration tests for key functionalities and edge cases.
- Maintain meaningful inline comments and documentation.
- Implement clear and transparent documentation for privileged roles and sensitive protocol operations.
- Regularly review and simulate contract behavior against newly emerging attack vectors.

---

## Findings Summary Table

| ID | Title | Category | Severity | Status |
|----|-------|----------|----------|--------|
| QVB-06 | Centralization Risk | Centralization | Centralization | 2/3 Multi-Sig |
| QVB-07 | Centralization Risk In QubicBridge.sol | Centralization | Centralization | Acknowledged |
| QVB-08 | Emergency Withdraw Function Allows Extraction Of Bridge Tokens | Centralization | Centralization | Resolved |
| QVB-09 | `createOrder()` Allows Zero-Fee Spam Orders Leading To DoS | Logical Issue | **Major** | Pending |
| QVB-10 | `transferToContract()` Locks User Funds On Validation Failure | Logical Issue | **Medium** | Pending |
| QVB-11 | `createOrder()` Fails To Refund Excess `invocationReward` | Logical Issue | **Medium** | Pending |
| QVB-12 | Premature Fee Reserve Updates In `refundOrder()` | Logical Issue | **Medium** | Pending |
| QVB-13 | Incorrect Transfer Success Check In `END_TICK_WITH_LOCALS()` | Coding Issue | **Medium** | Pending |
| QVB-14 | Possible Loss Of Data Due To Indexed Dynamic Data Type In Event | Design Issue | Minor | Resolved |
| QVB-15 | Missing Zero Address Validation | Volatile Code | Minor | Resolved |
| QVB-16 | Inconsistent Error Code Usage In `createOrder()` | Inconsistency | Minor | Pending |
| QVB-17 | `createOrder()` Increments `nextOrderId` Before Validation | Logical Issue | Minor | Pending |
| QVB-18 | Missing Input Validation In Multiple Functions | Logical Issue | Minor | Pending |
| QVB-19 | Uninitialized Struct Fields In Proposal Cleanup | Volatile Code | Minor | Pending |
| QVB-20 | Silent Proposal Execution Failures In `approveProposal()` | Logical Issue | Minor | Pending |
| QVB-21 | Ambiguous `tokensLocked` State Handling In `refundOrder()` | Logical Issue | Minor | Pending |
| QVB-22 | Silent Token Consumption For EVM-To-Qubic Orders In `transferToContract()` | Logical Issue | Minor | Pending |
| QVB-23 | Multisig And Bridge Functionality Mixed In Single Contract | Coding Issue / Code Optimization | Minor | Acknowledged |
| QVB-24 | Contract Address Included In Admin Role With Unclear Purpose | Inconsistency | Minor | Resolved |
| QVB-25 | Missing Existence Check In `removeAdmin()` Function | Inconsistency | Minor | Resolved |
| QVB-26 | Generic Error Usage In `proposeAction()` Masks Different Failure Conditions | Coding Style | Minor | Resolved |
| QVB-27 | Inconsistent Documentation And Implementation | Inconsistency | Informational | Resolved |
| QVB-28 | Missing Interface Inheritance For Contract Implementation | Coding Issue | Informational | Resolved |
| QVB-29 | Internal Function `getTransferFee()` Should Be Public Or Renamed With Underscore | Coding Style / Inconsistency | Informational | Resolved |

---

## Findings Detail

---

### QVB-06: Centralization Risk

| | |
|---|---|
| **Category** | Centralization |
| **Severity** | Centralization |
| **Location** | `VottunBridge.h` (C++): lines 278~281 |
| **Status** | 2/3 Multi-Sig |

**Description:**
The `VottunBridge.h` contract implements multiple privileged roles with extensive control over user funds and operations, creating significant centralization risks.

**Key Privileged Roles and Their Powers:**

1. **Managers** (up to 3 addresses):
   - Can `completeOrder()` and `refundOrder()` for any order
   - Can add liquidity via `addLiquidity()`
   - Can manipulate order execution timing and refund decisions

2. **Multisig Admins** (3 addresses, 2-of-3 threshold):
   - Can create and approve proposals to:
     - Replace other admins (`PROPOSAL_SET_ADMIN`)
     - Add/remove managers (`PROPOSAL_ADD_MANAGER`, `PROPOSAL_REMOVE_MANAGER`)
     - Withdraw accumulated fees (`PROPOSAL_WITHDRAW_FEES`)
     - Change approval threshold (`PROPOSAL_CHANGE_THRESHOLD`)
   - Can also add liquidity via `addLiquidity()`

3. **Hardcoded Fee Recipient:**
   - Receives all operator fees (0.5% of each trade)
   - Address is hardcoded in initialization and cannot be changed

**Critical Concerns:**
- Managers can arbitrarily decide which orders to complete or refund
- Multisig admins can collude (2-of-3) to replace the third admin and gain full control
- No timelocks or delays on critical administrative actions
- No mechanism for users to withdraw funds if managers become unresponsive
- Hardcoded fee recipient creates permanent revenue stream to a single entity

**Recommendation:**
Implement timelocks for all administrative actions (minimum 24-48 hours).

---

### QVB-07: Centralization Risk In QubicBridge.sol

| | |
|---|---|
| **Category** | Centralization |
| **Severity** | Centralization |
| **Location** | `QubicBridge.sol` (Solidity): lines 51~53 |
| **Status** | 2/3 Multi-Sig |

**Description:**
The contract implements a multi-tiered role system (Admin, Manager, Operator) with significant centralization risks:

1. **Admin Privileges** - Admins can unilaterally:
   - Pause/unpause the entire bridge via `emergencyPause()` and `emergencyUnpause()`
   - Withdraw all tokens and ETH via `emergencyTokenWithdraw()` and `emergencyEtherWithdraw()`
   - Change fee recipient, base fee, and transfer limits
   - Add/remove other admins, managers, and operators

2. **Manager Privileges** - Managers can add/remove operators who control order execution.

3. **Operator Privileges** - Operators can:
   - Confirm or revert user orders with arbitrary fees (up to 100% of baseFee)
   - Execute incoming orders with fee extraction
   - Potentially censor transactions by not confirming orders

4. **Multisig Bypass** - While some functions require multisig approval, the multisig itself is controlled by the same privileged roles, creating circular trust.

5. **No Timelocks** - Critical operations like fee changes, emergency withdrawals, and role modifications can be executed immediately without user notification.

**Recommendation:**
1. **Timelocks**: Add delay for critical operations (24-72 hours) to allow users to react.
2. **Fee Caps**: Implement maximum fee percentages to prevent excessive extraction.
3. **Withdrawal Limits**: Forbid withdrawing of Wrapped Qubic via `emergencyTokenWithdraw()`.

---

### QVB-08: Emergency Withdraw Function Allows Extraction Of Bridge Tokens

| | |
|---|---|
| **Category** | Centralization |
| **Severity** | Centralization |
| **Location** | `QubicBridge.sol` (Solidity): lines 774~775 |
| **Status** | Pending |

**Description:**
The `emergencyTokenWithdraw()` function allows admins to withdraw ANY ERC20 token from the contract, including the bridge's own WQUBIC tokens. This creates significant risks:

1. **Bridge Token Theft**: Admins can steal WQUBIC tokens that represent user deposits waiting for bridge confirmation.
2. **Breaking Bridge Economics**: Removing WQUBIC tokens breaks the 1:1 peg between bridged and native tokens.
3. **User Fund Loss**: Users who deposited tokens for bridging could lose their funds.
4. **No Justification**: There's no legitimate reason to withdraw the bridge token itself since the token has mint/burn functionality for proper bridge operations.
5. **Centralization Risk**: This amplifies the existing centralization risk by allowing complete custodial control over user funds.

**Recommendation:**
Prevent withdrawal of the bridge token by adding a check:
```solidity
if (tokenAddress == token) {
    revert CannotWithdrawBridgeToken();
}
```

---

### QVB-09: `createOrder()` Allows Zero-Fee Spam Orders Leading To DoS

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | **Major** |
| **Location** | `VottunBridge.h` (C++): lines 360~363 |
| **Status** | Pending |

**Description:**
The `createOrder()` function contains three logical flaws that enable attackers to fill the order book with spam orders at zero cost, causing Denial of Service (DoS):

1. **Fee Calculation Rounding**: Integer division `div(input.amount * state._tradeFeeBillionths, 1000000000ULL)` rounds down to zero for small amounts (e.g., `amount < 200` with 0.5% fee).
2. **Unrestricted EVM-to-Qubic Orders**: EVM-to-Qubic orders (`fromQubicToEthereum = false`) don't require principal deposit, only check `state.lockedTokens` sufficiency without reserving liquidity, allowing unlimited reuse of the same liquidity.
3. **No Minimum Fee/Deposit**: Absence of minimum fee or deposit requirements enables zero-cost order creation.

**Attack Scenario:**
1. Attacker calls `createOrder()` with `amount = 1`, `fromQubicToEthereum = false`
2. Fee calculation: `1 * 5000000 / 1000000000 = 0`
3. Fee check passes (`0 < 0` fails, considered sufficient)
4. `state.lockedTokens` check passes (contract has >= 1 liquidity)
5. Order created, occupying slot
6. Repeat 1024 times to fill all slots
7. Legitimate users receive error status 3 (no available slots)

**Recommendation:**
1. Enforce minimum order amount that yields non-zero fee.
2. Reserve liquidity for EVM-to-Qubic orders by decrementing `state.lockedTokens` on creation.
3. Implement minimum fee requirement or flat creation fee.
4. Consider rate-limiting or spam prevention mechanisms.

---

### QVB-10: `transferToContract()` Locks User Funds On Validation Failure

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | **Medium** |
| **Location** | `VottunBridge.h` (C++): lines 1699~1700, 1856~1857, 1871~1872 |
| **Status** | Pending |

**Description:**
The `transferToContract()` function fails to refund tokens attached to the transaction when early validation checks fail. In the Qubic environment, tokens sent with a transaction (accessed via `qpi.invocationReward()`) remain held by the contract unless explicitly transferred back. If any validation fails, the function returns an error without refunding the attached tokens, causing permanent loss of user funds.

The tokens remain in the contract's balance but are not accounted for in `lockedTokens`, making them irretrievable. `addLiquidity` is also affected.

**Scenario:**
1. User calls `transferToContract()` with an invalid `orderId` (non-existent order)
2. The function validates and finds no matching order
3. Function returns `orderNotFound` error without calling `qpi.transfer()` to refund attached tokens
4. User's tokens are permanently locked in contract balance

**Recommendation:**
Immediately capture `qpi.invocationReward()` at function start and refund it on any early validation failure before returning. Add a safety transfer for any remaining balance after successful execution.

---

### QVB-11: `createOrder()` Fails To Refund Excess `invocationReward`

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | **Medium** |
| **Location** | `VottunBridge.h` (C++): lines 365~366 |
| **Status** | Pending |

**Description:**
The `createOrder()` function does not refund excess `invocationReward` when users send more tokens than required for fees. The function calculates required fees and checks if `qpi.invocationReward() >= totalRequiredFee`, but if the user sends more tokens than needed, the excess amount remains locked in the contract balance without being accounted for in any state variable.

Additionally, when validation errors occur (invalid amount, insufficient fee, insufficient locked tokens, or no available slots), the function returns an error status but does not refund any attached tokens, causing permanent loss of user funds.

**Scenario:**
1. User calls `createOrder()` with `amount = 1000`, sending 1500 tokens as `invocationReward`
2. Required fee calculates to 1000 tokens
3. Order creation succeeds, but 500 excess tokens remain in contract balance
4. Alternatively, if order creation fails due to validation, all attached tokens are lost

**Recommendation:**
1. Immediately capture `qpi.invocationReward()` at function start.
2. On success, refund `invocationReward - totalRequiredFee` if positive.
3. On any error, refund the entire `invocationReward` before returning.
4. Consider using `qpi.transfer()` to return excess funds.

---

### QVB-12: Premature Fee Reserve Updates In `refundOrder()`

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | **Medium** |
| **Location** | `VottunBridge.h` (C++): lines 1527~1538 |
| **Status** | Pending |

**Description:**
In `refundOrder()`, fee reserves (`state._reservedFees`, `state._earnedFees`, `state._reservedFeesQubic`, `state._earnedFeesQubic`) are decremented before verifying the token transfer succeeds:

```cpp
// Fee reserves decremented before transfer
if (state._reservedFees >= locals.feeOperator && state._earnedFees >= locals.feeOperator) {
    state._reservedFees -= locals.feeOperator;
    state._earnedFees -= locals.feeOperator;
    locals.totalRefund += locals.feeOperator;
}
// Transfer attempted later
if (qpi.transfer(locals.order.qubicSender, locals.totalRefund) < 0) {
    // Returns error but fee reserves already reduced
    output.status = EthBridgeError::transferFailed;
    return;
}
```

If the transfer fails, fee reserves are permanently reduced without the user receiving the refund, creating an inconsistent state.

**Recommendation:**
Update fee reserves only after confirming successful token transfer:
1. Calculate total refund amount
2. Attempt transfer
3. If transfer succeeds, update fee reserves and order status
4. If transfer fails, revert completely without state changes

---

### QVB-13: Incorrect Transfer Success Check In `END_TICK_WITH_LOCALS()`

| | |
|---|---|
| **Category** | Coding Issue |
| **Severity** | **Medium** |
| **Location** | `VottunBridge.h` (C++): lines 2010~2011 |
| **Status** | Pending |

**Description:**
The `END_TICK_WITH_LOCALS()` function uses an incorrect condition to check the success of `qpi.transfer()`:

```cpp
if (qpi.transfer(state.feeRecipient, locals.vottunFeesToDistribute)) {
    state._distributedFees += locals.vottunFeesToDistribute;
}
```

In Qubic's QPI, `qpi.transfer()` returns a signed integer (`sint64`) where:
- Negative values indicate failure
- Zero or positive values indicate success

The current check `if (qpi.transfer(...))` evaluates to `true` for any non-zero return value, which **includes negative error codes**. This could cause `_distributedFees` to be incremented even when the transfer failed.

**Recommendation:**
Change the transfer success check to:
```cpp
if (qpi.transfer(state.feeRecipient, locals.vottunFeesToDistribute) >= 0) {
    state._distributedFees += locals.vottunFeesToDistribute;
}
```

---

### QVB-14: Possible Loss Of Data Due To Indexed Dynamic Data Type In Event

| | |
|---|---|
| **Category** | Design Issue |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 101, 107, 113, 118 |
| **Status** | Pending |

**Description:**
When indexing dynamic data types like `string`, `bytes`, `array`, or `struct` in Solidity, they don't get stored in their original form. Instead, the Ethereum log system stores the Keccak-256 hash of these data types. The original string cannot be retrieved from its hash alone.

**Recommendation:**
Revise the design; acknowledge that the original string cannot be retrieved directly from the logging event.

---

### QVB-15: Missing Zero Address Validation

| | |
|---|---|
| **Category** | Volatile Code |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 276~277 |
| **Status** | Pending |

**Description:**
The cited address input is missing a check that it is not `address(0)`.

**Recommendation:**
Add a check that the passed-in address is not `address(0)` to prevent unexpected errors.

---

### QVB-16: Inconsistent Error Code Usage In `createOrder()`

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 355~356 |
| **Status** | Pending |

**Description:**
The `createOrder()` function uses inconsistent error codes in its return values:

1. **Invalid amount check**: Returns `output.status = 1` but `EthBridgeError::invalidAmount` is defined as `2`.
2. **No available slots**: Returns `output.status = 3` but logs error code `99`, and `EthBridgeError::insufficientTransactionFee` is defined as `3`.
3. **Insufficient transaction fee**: Correctly returns `output.status = EthBridgeError::insufficientTransactionFee` (value 3).
4. **Insufficient locked tokens**: Correctly returns `output.status = EthBridgeError::insufficientLockedTokens` (value 6).

**Recommendation:**
Standardize all error returns to use the defined `EthBridgeError` enum values consistently:
- Use `EthBridgeError::invalidAmount` (2) for invalid amounts
- Use `EthBridgeError::insufficientTransactionFee` (3) for fee issues
- Define and use a specific error code for "no available slots"
- Ensure logged error codes match returned status codes

---

### QVB-17: `createOrder()` Increments `nextOrderId` Before Validation

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 379~380 |
| **Status** | Pending |

**Description:**
The `createOrder()` function increments `state.nextOrderId` at the beginning of successful order creation (`locals.newOrder.orderId = state.nextOrderId++`) before performing critical validations. If validations fail, the function returns an error but `nextOrderId` has already been incremented, causing order ID gaps.

**Recommendation:**
Move `state.nextOrderId` increment to after all validations pass, just before storing the order in the array.

---

### QVB-18: Missing Input Validation In Multiple Functions

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 410~411 |
| **Status** | Pending |

**Description:**
Several functions lack proper input validation:

1. **`createOrder()` - Ethereum Address Validation**: Copies only the first 42 bytes of `ethAddress` but doesn't validate the address format.
2. **`createProposal()` - Proposal Parameter Validation**:
   - No validation that `targetAddress` is not `NULL_ID` for `PROPOSAL_SET_ADMIN`, `PROPOSAL_ADD_MANAGER`, `PROPOSAL_REMOVE_MANAGER`
   - No validation that `oldAddress` exists in admin list for `PROPOSAL_SET_ADMIN`
   - No validation that `amount` is within reasonable bounds for `PROPOSAL_WITHDRAW_FEES` and `PROPOSAL_CHANGE_THRESHOLD`
   - No check that `targetAddress` is not already an admin/manager when adding
3. **`approveProposal()` - Execution Validation**: No validation that proposal parameters are still valid at execution time.

**Recommendation:**
1. Add Ethereum address validation (non-zero, proper length/format).
2. Validate all proposal parameters in `createProposal()`.
3. Add re-validation in `approveProposal()` before execution.

---

### QVB-19: Uninitialized Struct Fields In Proposal Cleanup

| | |
|---|---|
| **Category** | Volatile Code |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 459~462, 692~693 |
| **Status** | Pending |

**Description:**
In `createProposal()`, when cleaning proposal slots, `locals.emptyProposal` is declared but not fully initialized before being written to storage. Only specific fields are set:

```cpp
locals.emptyProposal.proposalId = 0;
locals.emptyProposal.proposalType = 0;
locals.emptyProposal.approvalsCount = 0;
locals.emptyProposal.executed = false;
locals.emptyProposal.active = false;
// targetAddress, oldAddress, amount, and approvals array remain uninitialized
```

Uninitialized fields contain garbage values from stack/memory. `locals.emptyOrder` in `createOrder()` is also affected.

**Recommendation:**
1. Fully initialize `locals.emptyProposal` using a constructor or explicit assignment of all fields.
2. Set `targetAddress = NULL_ID`, `oldAddress = NULL_ID`, `amount = 0`.
3. Iterate through `approvals` array setting each element to `NULL_ID`.

---

### QVB-20: Silent Proposal Execution Failures In `approveProposal()`

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 992~995 |
| **Status** | Pending |

**Description:**
The `approveProposal()` function has multiple issues where proposals can be marked as executed without actually performing their intended actions:

1. **Duplicate Admin Check**: If `targetAddress` is already an admin in `PROPOSAL_SET_ADMIN`, the proposal is marked as executed but no change occurs.
2. **Incorrect Admin Array Iteration**: The loop `for (locals.i = 0; locals.i < state.admins.capacity(); ++locals.i)` should iterate only up to `state.numberOfAdmins`.
3. **Manager Limit Bypass**: For `PROPOSAL_ADD_MANAGER`, if `locals.managerCount >= 3`, the proposal is marked as executed without adding the manager.
4. **Zero Amount Withdrawal**: `PROPOSAL_WITHDRAW_FEES` with `amount == 0` is silently ignored.
5. **Invalid Threshold Change**: `PROPOSAL_CHANGE_THRESHOLD` with invalid `amount` (outside 2-numberOfAdmins range) is ignored without error.

**Recommendation:**
1. Validate proposal parameters before marking as executed.
2. Return distinct error codes for invalid parameters.
3. Cancel proposals with invalid parameters rather than silently ignoring them.
4. Fix admin array iteration to use `numberOfAdmins` as bound.

---

### QVB-21: Ambiguous `tokensLocked` State Handling In `refundOrder()`

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 1478~1490 |
| **Status** | Pending |

**Description:**
The `refundOrder()` function contains unclear logic when handling the state `locals.order.tokensReceived == true` but `locals.order.tokensLocked == false` for Qubic-to-Ethereum orders:

```cpp
if (!locals.order.tokensLocked) {
    locals.log = EthBridgeLogger{...}; // Error: invalidOrderState
    LOG_INFO(locals.log);
    output.status = EthBridgeError::invalidOrderState;
    return;
}
```

If this state somehow occurs, the order becomes stuck: it cannot be completed (requires `tokensLocked = true`) nor refunded (this check fails), with no resolution path.

**Recommendation:**
1. Clarify the intended meaning of `tokensLocked` vs `tokensReceived` states.
2. Either ensure the two flags are always set together, or provide a recovery mechanism.
3. Consider removing the `tokensLocked` flag if redundant with `tokensReceived`.
4. Add an admin function to manually fix inconsistent order states if needed.

---

### QVB-22: Silent Token Consumption For EVM-To-Qubic Orders In `transferToContract()`

| | |
|---|---|
| **Category** | Logical Issue |
| **Severity** | Minor |
| **Location** | `VottunBridge.h` (C++): lines 1668~1669 |
| **Status** | Pending |

**Description:**
The `transferToContract()` function incorrectly handles EVM-to-Qubic orders (`locals.order.fromQubicToEthereum == false`). For these orders, tokens should NOT be transferred to the contract. However, the function accepts the transaction with attached tokens, performs all validations, returns success status `0`, and does not refund the attached tokens - effectively burning user funds.

**Recommendation:**
Add explicit check: if `!locals.order.fromQubicToEthereum`, immediately refund any attached tokens and return an error.

---

### QVB-23: Multisig And Bridge Functionality Mixed In Single Contract

| | |
|---|---|
| **Category** | Coding Issue / Code Optimization |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 39~49 |
| **Status** | Pending |

**Description:**
The `QubicBridge` contract combines two distinct concerns: bridge functionality and multisig/proposal management. This violates the Single Responsibility Principle:

1. **Increased Contract Size**: Over 800 lines, approaching the 24KB limit.
2. **Complexity**: Multisig logic adds significant complexity to bridge operations.
3. **Gas Inefficiency**: Users pay for multisig-related storage even for simple bridge operations.
4. **Maintainability**: Changes to either functionality risk breaking the other.
5. **Testing Complexity**: Testing becomes more difficult with intertwined concerns.

**Recommendation:**
Split into two separate contracts:
1. **Bridge Contract**: Only bridge-specific logic (createOrder, confirmOrder, revertOrder, executeOrder, fee management).
2. **Multisig Contract**: Proposal creation, approval, and execution logic that can call the Bridge contract via delegatecall or external calls.

---

### QVB-24: Contract Address Included In Admin Role With Unclear Purpose

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 314~317 |
| **Status** | Pending |

**Description:**
The contract address (`address(this)`) is included in the `DEFAULT_ADMIN_ROLE` with unclear purpose:

1. **Unclear Purpose**: No documentation explaining why this is needed.
2. **Cannot Be Removed**: `removeAdmin()` prevents removal of the contract address.
3. **Admin Count Inconsistency**: Counting logic excludes the contract address when checking thresholds, but it still occupies a role slot.
4. **Role Slot Consumption**: Cannot be added via `addAdmin()` if 3 human admins already exist.

`MANAGER_ROLE` is also affected.

**Recommendation:**
1. Document why the contract needs admin role or remove it entirely.
2. If needed, update `MAX_ADMINS` to 4 and adjust counting logic consistently.
3. Consider using a separate role for contract self-calls instead of `DEFAULT_ADMIN_ROLE`.

---

### QVB-25: Missing Existence Check In `removeAdmin()` Function

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 353~354 |
| **Status** | Pending |

**Description:**
The `removeAdmin()` function lacks a check to verify if the address being removed actually has the admin role, unlike `addAdmin()` which checks `hasRole(DEFAULT_ADMIN_ROLE, newAdmin)`.

**Recommendation:**
Add a role existence check similar to `addAdmin()`.

---

### QVB-26: Generic Error Usage In `proposeAction()` Masks Different Failure Conditions

| | |
|---|---|
| **Category** | Coding Style |
| **Severity** | Minor |
| **Location** | `QubicBridge.sol` (Solidity): lines 817~822 |
| **Status** | Pending |

**Description:**
The `proposeAction()` function uses the same `UnauthorizedRole` error for three distinct failure conditions, making debugging and error handling difficult.

**Recommendation:**
Create specific error types for each failure condition:
```solidity
error CallerLacksRole();
error InvalidRoleType();
error FunctionNotRegistered();
error RoleMismatch();
error InvalidDataLength();
```

---

### QVB-27: Inconsistent Documentation And Implementation

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Informational |
| **Location** | `QubicBridge.sol` (Solidity): lines 61, 927~928, 1063 |
| **Status** | Pending |

**Description:**
The contract contains several inconsistencies between code comments, NatSpec documentation, and actual implementation:

1. **Obsolete Comments**: `feeRecipient` is not actually constant.
2. **Incorrect NatSpec**: `getAdmins()` documentation states "Gets all admins (excluding the contract itself)" but the implementation returns all role members including the contract itself.
3. **Misleading Documentation**: `cancelProposal()` NatSpec says "only proposer can cancel" but the code allows both the proposer AND any admin to cancel proposals.
4. **Missing Documentation**: Several functions lack proper NatSpec documentation.

**Recommendation:**
1. Remove obsolete comments and clean up code.
2. Update all NatSpec documentation to accurately reflect the implementation.

---

### QVB-28: Missing Interface Inheritance For Contract Implementation

| | |
|---|---|
| **Category** | Coding Issue |
| **Severity** | Informational |
| **Location** | `QubicBridge.sol` (Solidity): line 9 |
| **Status** | Pending |

**Description:**
Both `QubicBridge.sol` and `QubicToken.sol` implement their functionality directly without inheriting from or implementing explicit interface contracts. This leads to:

1. Lack of explicit contract API
2. Integration difficulties for other contracts
3. Upgradeability challenges
4. Documentation gap

**Recommendation:**
Create and inherit interface files for both contracts.

---

### QVB-29: Internal Function `getTransferFee()` Should Be Public Or Renamed With Underscore

| | |
|---|---|
| **Category** | Coding Style / Inconsistency |
| **Severity** | Informational |
| **Location** | `QubicBridge.sol` (Solidity): line 1037 |
| **Status** | Pending |

**Description:**
The `getTransferFee()` function is marked as `internal` but follows naming conventions typically used for public/external functions. Solidity convention uses leading underscore (`_`) for internal/private functions. Other internal helpers like `_removePendingProposal()` correctly use underscore prefix.

**Recommendation:**
Either:
1. Make it `public` (preferred if external access is useful for fee previews).
2. Rename to `_getTransferFee()` if it should remain internal-only.

---

## Optimizations

| ID | Title | Category | Severity | Status |
|----|-------|----------|----------|--------|
| QVB-01 | Unused Function Arguments And Local Variables | Code Optimization | Optimization | Pending |
| QVB-02 | Suboptimal Order Slot Recycling Logic In `createOrder()` | Code Optimization | Optimization | Pending |
| QVB-03 | Overcomplicated And Redundant Proposal Slot Management In `createProposal()` | Code Optimization | Optimization | Pending |
| QVB-04 | Redundant Variable `locals.netAmount` In `completeOrder()` | Code Optimization | Optimization | Pending |
| QVB-05 | Redundant Validation In `isQubicAddress()` Function | Code Optimization | Optimization | Resolved |

---

### QVB-01: Unused Function Arguments And Local Variables

| | |
|---|---|
| **Category** | Code Optimization |
| **Severity** | Optimization |
| **Location** | `VottunBridge.h` (C++): lines 62~63, 147~148, 516~517, 1171~1172, 1764~1765 |
| **Status** | Pending |

**Description:**
Several function input arguments and local variables are declared but never used:

- `getTotalReceivedTokens_input::amount` - Input parameter never used
- `getTotalReceivedTokens_locals::log` - Local variable never used
- `getTotalLockedTokens_locals::log` - Local variable never used
- `refundOrder_locals::availableFeesOperator` and `availableFeesNetwork` - Variables never used

**Recommendation:**
Remove all unused input arguments and local variable declarations.

---

### QVB-02: Suboptimal Order Slot Recycling Logic In `createOrder()`

| | |
|---|---|
| **Category** | Code Optimization |
| **Severity** | Optimization |
| **Location** | `VottunBridge.h` (C++): lines 453~455 |
| **Status** | Pending |

**Description:**
The `createOrder()` function implements a three-pass algorithm for finding available order slots when a two-pass approach would suffice:

1. **Pass 1**: Search for empty slots (`status == 255`)
2. **Pass 2**: If no empty slots, clean completed/refunded orders (`status == 1 || status == 2`)
3. **Pass 3**: Search again for empty slots after cleanup

When the orders array is full with active orders: 3072 iterations instead of optimal 1024.

**Recommendation:**
Refactor to two-pass logic:
1. First pass: Find empty slot OR track first completed/refunded slot
2. If empty slot found -> use it
3. If no empty slot but recyclable slot tracked -> clean and use it
4. If neither -> return error immediately

---

### QVB-03: Overcomplicated And Redundant Proposal Slot Management In `createProposal()`

| | |
|---|---|
| **Category** | Code Optimization |
| **Severity** | Optimization |
| **Location** | `VottunBridge.h` (C++): lines 659~661 |
| **Status** | Pending |

**Description:**
The `createProposal()` function contains redundant and overcomplicated logic for finding available proposal slots, resulting in up to 3 full iterations through the proposals array (32 elements each) when one efficient pass would suffice.

**Recommendation:**
Simplify to single-pass algorithm:
1. Iterate once, tracking first empty slot and first recyclable slot
2. Use empty slot if found, otherwise use recyclable slot
3. If neither found, return error immediately

---

### QVB-04: Redundant Variable `locals.netAmount` In `completeOrder()`

| | |
|---|---|
| **Category** | Code Optimization |
| **Severity** | Optimization |
| **Location** | `VottunBridge.h` (C++): lines 1255~1256 |
| **Status** | Pending |

**Description:**
The `completeOrder()` function declares `locals.netAmount = locals.order.amount` but then uses `locals.order.amount` directly in all subsequent logic. The variable is redundant.

**Recommendation:**
Remove `locals.netAmount` and use `locals.order.amount` directly.

---

### QVB-05: Redundant Validation In `isQubicAddress()` Function

| | |
|---|---|
| **Category** | Code Optimization |
| **Severity** | Optimization |
| **Location** | `QubicBridge.sol` (Solidity): lines 1161~1162 |
| **Status** | Pending |

**Description:**
The `isQubicAddress()` function contains a redundant `allZeros` check that is already covered by the `allSame` validation.

**Recommendation:**
Remove the redundant `allZeros` check.

---

## Appendix: Finding Categories

| Category | Description |
|----------|-------------|
| **Coding Style** | May not affect code behavior, but indicate areas where coding practices can be improved for understandability and maintainability. |
| **Coding Issue** | General code quality issues including coding mistakes, compile errors, and performance issues. |
| **Inconsistency** | Different parts of code that are not consistent or code that does not behave according to its specification. |
| **Volatile Code** | Segments of code that behave unexpectedly on certain edge cases and may result in vulnerabilities. |
| **Logical Issue** | General implementation issues related to the program logic. |
| **Centralization** | Design choices of designating privileged roles or other centralized controls over the code. |
| **Design Issue** | General issues at the design level beyond program logic. |

---

## Disclaimer

This report is subject to the terms and conditions set forth in the Services Agreement. This report is not, nor should be considered, an "endorsement" or "disapproval" of any particular project or team, an indication of the economics or value of any "product" or "asset", nor does it provide any warranty or guarantee regarding the absolute bug-free nature of the technology analyzed.

This report should not be used in any way to make decisions around investment or involvement with any particular project. This report in no way provides investment advice, nor should be leveraged as investment advice of any sort.

ALL SERVICES, THE ASSESSMENT REPORT, WORK PRODUCT, OR OTHER MATERIALS ARE PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTY OF ANY KIND.

---

*Qubic - Vottun Bridge Preliminary Comments | CertiK | Assessed on Feb 18th, 2026 | Copyright CertiK*
