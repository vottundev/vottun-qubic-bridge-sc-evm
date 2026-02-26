# Audit Findings: VottunBridge.h (C++ / Qubic)

**Source**: CertiK Preliminary Comments | Feb 18th, 2026
**Repository**: [sergimima/core-1](https://github.com/sergimima/core-1/blob/9b3521ce1c3078123b73cb028227495e0e8df5d0/src/contracts/VottunBridge.h)
**Commit**: `9b3521ce1c3078123b73cb028227495e0e8df5d0`

---

## Summary

| Severity | Count | IDs |
|----------|:-----:|-----|
| Centralization | 1 | QVB-06 |
| Major | 1 | QVB-09 |
| Medium | 4 | QVB-10, QVB-11, QVB-12, QVB-13 |
| Minor | 7 | QVB-16, QVB-17, QVB-18, QVB-19, QVB-20, QVB-21, QVB-22 |
| Optimization | 4 | QVB-01, QVB-02, QVB-03, QVB-04 |
| **Total** | **17** | |

---

## Centralization

### QVB-06: Centralization Risk

| | |
|---|---|
| **Severity** | Centralization |
| **Location** | Lines 278~281 |
| **Status** | 2/3 Multi-Sig |

**Description:**
The contract implements multiple privileged roles with extensive control over user funds and operations:

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

## Major

### QVB-09: `createOrder()` Allows Zero-Fee Spam Orders Leading To DoS

| | |
|---|---|
| **Severity** | **Major** |
| **Location** | Lines 360~363 |
| **Status** | Pending |

**Description:**
The `createOrder()` function contains three logical flaws that enable attackers to fill the order book with spam orders at zero cost, causing Denial of Service (DoS):

1. **Fee Calculation Rounding**: Integer division `div(input.amount * state._tradeFeeBillionths, 1000000000ULL)` rounds down to zero for small amounts (e.g., `amount < 200` with 0.5% fee).
2. **Unrestricted EVM-to-Qubic Orders**: EVM-to-Qubic orders (`fromQubicToEthereum = false`) don't require principal deposit, only check `state.lockedTokens` sufficiency without reserving liquidity.
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

## Medium

### QVB-10: `transferToContract()` Locks User Funds On Validation Failure

| | |
|---|---|
| **Severity** | **Medium** |
| **Location** | Lines 1699~1700, 1856~1857, 1871~1872 |
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
| **Severity** | **Medium** |
| **Location** | Lines 365~366 |
| **Status** | Pending |

**Description:**
The `createOrder()` function does not refund excess `invocationReward` when users send more tokens than required for fees. The function calculates required fees and checks if `qpi.invocationReward() >= totalRequiredFee`, but excess tokens remain locked in the contract balance.

Additionally, when validation errors occur, the function returns an error status but does not refund any attached tokens, causing permanent loss of user funds.

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
| **Severity** | **Medium** |
| **Location** | Lines 1527~1538 |
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

If the transfer fails, fee reserves are permanently reduced without the user receiving the refund.

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
| **Severity** | **Medium** |
| **Location** | Lines 2010~2011 |
| **Status** | Pending |

**Description:**
The `END_TICK_WITH_LOCALS()` function uses an incorrect condition to check the success of `qpi.transfer()`:

```cpp
if (qpi.transfer(state.feeRecipient, locals.vottunFeesToDistribute)) {
    state._distributedFees += locals.vottunFeesToDistribute;
}
```

In Qubic's QPI, `qpi.transfer()` returns a signed integer (`sint64`) where:
- **Negative values** = failure
- **Zero or positive** = success

The current check `if (qpi.transfer(...))` evaluates to `true` for any non-zero return value, **including negative error codes**. This causes `_distributedFees` to be incremented even when the transfer failed.

**Recommendation:**
```cpp
if (qpi.transfer(state.feeRecipient, locals.vottunFeesToDistribute) >= 0) {
    state._distributedFees += locals.vottunFeesToDistribute;
}
```

---

## Minor

### QVB-16: Inconsistent Error Code Usage In `createOrder()`

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 355~356 |
| **Status** | Pending |

**Description:**
The `createOrder()` function uses inconsistent error codes:

1. **Invalid amount**: Returns `output.status = 1` but `EthBridgeError::invalidAmount` is defined as `2`.
2. **No available slots**: Returns `output.status = 3` but logs error code `99`, and `EthBridgeError::insufficientTransactionFee` is defined as `3`.
3. **Insufficient fee**: Correctly returns `EthBridgeError::insufficientTransactionFee` (value 3).
4. **Insufficient locked tokens**: Correctly returns `EthBridgeError::insufficientLockedTokens` (value 6).

**Recommendation:**
Standardize all error returns to use the defined `EthBridgeError` enum values consistently. Define a specific error code for "no available slots".

---

### QVB-17: `createOrder()` Increments `nextOrderId` Before Validation

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 379~380 |
| **Status** | Pending |

**Description:**
The function increments `state.nextOrderId` (`locals.newOrder.orderId = state.nextOrderId++`) before performing critical validations. If validations fail, `nextOrderId` has already been incremented, causing order ID gaps.

**Recommendation:**
Move `state.nextOrderId` increment to after all validations pass, just before storing the order in the array.

---

### QVB-18: Missing Input Validation In Multiple Functions

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 410~411 |
| **Status** | Pending |

**Description:**
Several functions lack proper input validation:

1. **`createOrder()`**: Copies only the first 42 bytes of `ethAddress` but doesn't validate the address format.
2. **`createProposal()`**:
   - No validation that `targetAddress` is not `NULL_ID` for `PROPOSAL_SET_ADMIN`, `PROPOSAL_ADD_MANAGER`, `PROPOSAL_REMOVE_MANAGER`
   - No validation that `oldAddress` exists in admin list for `PROPOSAL_SET_ADMIN`
   - No validation that `amount` is within reasonable bounds for `PROPOSAL_WITHDRAW_FEES` and `PROPOSAL_CHANGE_THRESHOLD`
   - No check that `targetAddress` is not already an admin/manager when adding
3. **`approveProposal()`**: No validation that proposal parameters are still valid at execution time.

**Recommendation:**
1. Add Ethereum address validation (non-zero, proper length/format).
2. Validate all proposal parameters in `createProposal()`.
3. Add re-validation in `approveProposal()` before execution.

---

### QVB-19: Uninitialized Struct Fields In Proposal Cleanup

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 459~462, 692~693 |
| **Status** | Pending |

**Description:**
In `createProposal()`, when cleaning proposal slots, `locals.emptyProposal` is declared but not fully initialized before being written to storage:

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
Fully initialize all struct fields including `targetAddress = NULL_ID`, `oldAddress = NULL_ID`, `amount = 0`, and all `approvals` array elements to `NULL_ID`.

---

### QVB-20: Silent Proposal Execution Failures In `approveProposal()`

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 992~995 |
| **Status** | Pending |

**Description:**
Proposals can be marked as executed without actually performing their intended actions:

1. **Duplicate Admin Check**: If `targetAddress` is already an admin in `PROPOSAL_SET_ADMIN`, the proposal is marked as executed but no change occurs.
2. **Incorrect Admin Array Iteration**: Loop should iterate only up to `state.numberOfAdmins`, not `state.admins.capacity()`.
3. **Manager Limit Bypass**: For `PROPOSAL_ADD_MANAGER`, if `managerCount >= 3`, the proposal is marked as executed without adding the manager.
4. **Zero Amount Withdrawal**: `PROPOSAL_WITHDRAW_FEES` with `amount == 0` is silently ignored.
5. **Invalid Threshold Change**: `PROPOSAL_CHANGE_THRESHOLD` with invalid `amount` is ignored without error.

**Recommendation:**
1. Validate proposal parameters before marking as executed.
2. Return distinct error codes for invalid parameters.
3. Cancel proposals with invalid parameters rather than silently ignoring them.
4. Fix admin array iteration to use `numberOfAdmins` as bound.

---

### QVB-21: Ambiguous `tokensLocked` State Handling In `refundOrder()`

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 1478~1490 |
| **Status** | Pending |

**Description:**
The `refundOrder()` function contains unclear logic when handling the state `tokensReceived == true` but `tokensLocked == false`:

```cpp
if (!locals.order.tokensLocked) {
    output.status = EthBridgeError::invalidOrderState;
    return;
}
```

If this state occurs, the order becomes stuck: it cannot be completed (requires `tokensLocked = true`) nor refunded (this check fails), with no resolution path.

**Recommendation:**
1. Clarify the intended meaning of `tokensLocked` vs `tokensReceived` states.
2. Either ensure the two flags are always set together, or provide a recovery mechanism.
3. Consider removing the `tokensLocked` flag if redundant with `tokensReceived`.
4. Add an admin function to manually fix inconsistent order states.

---

### QVB-22: Silent Token Consumption For EVM-To-Qubic Orders In `transferToContract()`

| | |
|---|---|
| **Severity** | Minor |
| **Location** | Lines 1668~1669 |
| **Status** | Pending |

**Description:**
The `transferToContract()` function incorrectly handles EVM-to-Qubic orders (`fromQubicToEthereum == false`). For these orders, tokens should NOT be transferred to the contract. However, the function accepts the transaction, performs all validations, returns success status `0`, and does not refund the attached tokens - effectively burning user funds.

**Recommendation:**
Add explicit check: if `!locals.order.fromQubicToEthereum`, immediately refund any attached tokens and return an error.

---

## Optimizations

### QVB-01: Unused Function Arguments And Local Variables

| | |
|---|---|
| **Location** | Lines 62~63, 147~148, 516~517, 1171~1172, 1764~1765 |
| **Status** | Pending |

**Description:**
Several function input arguments and local variables are declared but never used:
- `getTotalReceivedTokens_input::amount`
- `getTotalReceivedTokens_locals::log`
- `getTotalLockedTokens_locals::log`
- `refundOrder_locals::availableFeesOperator` and `availableFeesNetwork`

**Recommendation:** Remove all unused input arguments and local variable declarations.

---

### QVB-02: Suboptimal Order Slot Recycling Logic In `createOrder()`

| | |
|---|---|
| **Location** | Lines 453~455 |
| **Status** | Pending |

**Description:**
Three-pass algorithm for finding available order slots when two-pass would suffice. Worst case: 3072 iterations instead of 1024.

**Recommendation:** Refactor to two-pass logic: first pass finds empty slot OR tracks first recyclable slot; second pass only if needed.

---

### QVB-03: Overcomplicated Proposal Slot Management In `createProposal()`

| | |
|---|---|
| **Location** | Lines 659~661 |
| **Status** | Pending |

**Description:**
Redundant and overcomplicated logic for finding available proposal slots. Up to 3 full iterations through 32-element array when one pass would suffice.

**Recommendation:** Simplify to single-pass algorithm tracking first empty and first recyclable slot.

---

### QVB-04: Redundant Variable `locals.netAmount` In `completeOrder()`

| | |
|---|---|
| **Location** | Lines 1255~1256 |
| **Status** | Pending |

**Description:**
`locals.netAmount = locals.order.amount` is assigned but `locals.order.amount` is used directly everywhere after.

**Recommendation:** Remove `locals.netAmount` and use `locals.order.amount` directly.
