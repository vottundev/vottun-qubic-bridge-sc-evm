# Audit Findings: QubicBridge.sol (Solidity / EVM)

**Source**: CertiK Preliminary Comments | Feb 18th, 2026
**Repository**: [vottundev/vottun-qubic-bridge-sc-evm](https://github.com/vottundev/vottun-qubic-bridge-sc-evm/tree/ca18ed4dc7cd00b31c347949ab50e3dec1191189/src)
**Commit**: `ca18ed4dc7cd00b31c347949ab50e3dec1191189`

---

## Summary

| Severity | Count | IDs |
|----------|:-----:|-----|
| Centralization | 2 | QVB-07, QVB-08 |
| Minor | 5 | QVB-14, QVB-15, QVB-23, QVB-24, QVB-25, QVB-26 |
| Informational | 3 | QVB-27, QVB-28, QVB-29 |
| Optimization | 1 | QVB-05 |
| **Total** | **11** | |

---

## Centralization

### QVB-07: Centralization Risk In QubicBridge.sol

| | |
|---|---|
| **Severity** | Centralization |
| **Location** | Lines 51~53 |
| **Status** | Won't Fix (By Design) |

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

4. **Multisig Bypass** - The multisig itself is controlled by the same privileged roles, creating circular trust.

5. **No Timelocks** - Critical operations can be executed immediately without user notification.

**Recommendation:**
1. **Timelocks**: Add delay for critical operations (24-72 hours) to allow users to react.
2. **Fee Caps**: Implement maximum fee percentages to prevent excessive extraction.
3. **Withdrawal Limits**: Forbid withdrawing of Wrapped Qubic via `emergencyTokenWithdraw()`.

**Resolution:** Won't fix. The centralization risk is already mitigated by the on-chain multisig system (2-of-3 threshold for admin operations). Adding timelocks is a product decision that would impact emergency response capability (e.g., pausing the bridge during an active exploit). The bridge token withdrawal concern is addressed separately in QVB-08.

---

### QVB-08: Emergency Withdraw Function Allows Extraction Of Bridge Tokens

| | |
|---|---|
| **Severity** | Centralization |
| **Location** | Lines 774~775 |
| **Status** | Resolved |

**Description:**
The `emergencyTokenWithdraw()` function allows admins to withdraw ANY ERC20 token from the contract, including the bridge's own WQUBIC tokens:

1. **Bridge Token Theft**: Admins can steal WQUBIC tokens representing user deposits waiting for bridge confirmation.
2. **Breaking Bridge Economics**: Removing WQUBIC tokens breaks the 1:1 peg between bridged and native tokens.
3. **User Fund Loss**: Users who deposited tokens for bridging could lose their funds.
4. **No Justification**: The token has mint/burn functionality for proper bridge operations - there's no legitimate reason to withdraw it.
5. **Centralization Risk**: Amplifies the existing centralization risk by allowing complete custodial control over user funds.

**Recommendation:**
Prevent withdrawal of the bridge token:
```solidity
if (tokenAddress == token) {
    revert CannotWithdrawBridgeToken();
}
```

**Solution Implemented:**
Added custom error `CannotWithdrawBridgeToken()` to `IQubicBridge.sol` and added the check at the beginning of `emergencyTokenWithdraw()` in `QubicBridge.sol`:
```solidity
if (tokenAddress == token) {
    revert CannotWithdrawBridgeToken();
}
```
The bridge token can no longer be withdrawn via emergency functions. Other ERC20 tokens accidentally sent to the contract can still be recovered.

---

## Minor

### QVB-14: Possible Loss Of Data Due To Indexed Dynamic Data Type In Event

| | |
|---|---|
| **Category** | Design Issue |
| **Severity** | Minor |
| **Location** | Lines 101, 107, 113, 118 |
| **Status** | Resolved |

**Description:**
When indexing dynamic data types like `string`, `bytes`, `array`, or `struct` in Solidity, the Ethereum log system stores the Keccak-256 hash instead of the original value. The original string cannot be retrieved from its hash alone.

**Recommendation:**
Revise the design; acknowledge that indexed dynamic types cannot be retrieved directly from logging events. Consider using non-indexed parameters for data that needs to be readable.

**Solution Implemented:**
Removed `indexed` keyword from all `string` parameters in the 4 affected events in `IQubicBridge.sol`:
- `OrderCreated`: `string destinationAccount` (was `string indexed`)
- `OrderConfirmed`: `string destinationAccount` (was `string indexed`)
- `OrderReverted`: `string destinationAccount` (was `string indexed`)
- `OrderExecuted`: `string originAccount` (was `string indexed`)

The string values are now stored as full data in the event logs, readable by frontends and indexers.

---

### QVB-15: Missing Zero Address Validation

| | |
|---|---|
| **Category** | Volatile Code |
| **Severity** | Minor |
| **Location** | Lines 276~277 |
| **Status** | Resolved |

**Description:**
The cited address input is missing a check that it is not `address(0)`.

**Recommendation:**
Add a check that the passed-in address is not `address(0)` to prevent unexpected errors.

**Solution Implemented:**
Added zero address validation for the `_token` parameter in the `QubicBridge` constructor:
```solidity
if (_token == address(0)) {
    revert InvalidAddress();
}
```
This prevents deploying the bridge with an invalid token address.

---

### QVB-23: Multisig And Bridge Functionality Mixed In Single Contract

| | |
|---|---|
| **Category** | Coding Issue / Code Optimization |
| **Severity** | Minor |
| **Location** | Lines 39~49 |
| **Status** | Won't Fix (By Design) |

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

**Resolution:** Won't fix. Splitting the contract is a major architectural refactor that is out of scope for this audit fix pass. The current contract size is well within the 24KB limit and the integrated multisig design was a deliberate architectural choice to simplify deployment and avoid cross-contract trust issues.

---

### QVB-24: Contract Address Included In Admin Role With Unclear Purpose

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Minor |
| **Location** | Lines 314~317 |
| **Status** | Resolved |

**Description:**
The contract address (`address(this)`) is included in the `DEFAULT_ADMIN_ROLE` with unclear purpose:

1. **Unclear Purpose**: No documentation explaining why this is needed.
2. **Cannot Be Removed**: `removeAdmin()` prevents removal of the contract address:
   ```solidity
   if (admin == address(this)) {
       revert InvalidAddress();
   }
   ```
3. **Admin Count Inconsistency**: Counting logic excludes the contract address when checking thresholds, but it still occupies a role slot.
4. **Role Slot Consumption**: Cannot be added via `addAdmin()` if 3 human admins already exist.

`MANAGER_ROLE` is also affected.

**Recommendation:**
1. Document why the contract needs admin role or remove it entirely.
2. If needed, update `MAX_ADMINS` to 4 and adjust counting logic consistently.
3. Consider using a separate role for contract self-calls instead of `DEFAULT_ADMIN_ROLE`.

**Solution Implemented:**
Added defensive comments to all admin/manager counting loops explaining the `address(this)` exclusion pattern. The contract grants itself admin role to enable `executeProposal()` to call `onlyProposal`-protected functions via `address(this).call(data)`. The exclusion in counting loops is defensive coding to ensure `address(this)` never counts toward human admin/manager thresholds. Comments added to:
- `addAdmin()`, `removeAdmin()`, `addManager()`, `removeManager()`
- `setAdminThreshold()`, `setManagerThreshold()`

---

### QVB-25: Missing Existence Check In `removeAdmin()` Function

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Minor |
| **Location** | Lines 353~354 |
| **Status** | Resolved |

**Description:**
The `removeAdmin()` function lacks a check to verify if the address being removed actually has the admin role, unlike `addAdmin()` which checks `hasRole(DEFAULT_ADMIN_ROLE, newAdmin)`.

**Recommendation:**
Add a role existence check similar to `addAdmin()`.

**Solution Implemented:**
Added `hasRole` validation in all three remove functions for consistency:

`removeAdmin()`:
```solidity
if (!hasRole(DEFAULT_ADMIN_ROLE, admin)) {
    revert InvalidAddress();
}
```

`removeManager()`:
```solidity
if (manager == address(this)) {
    revert InvalidAddress();
}
if (!hasRole(MANAGER_ROLE, manager)) {
    revert InvalidAddress();
}
```

`removeOperator()`:
```solidity
if (!hasRole(OPERATOR_ROLE, operator)) {
    revert InvalidAddress();
}
```

This prevents attempting to remove an address that does not actually hold the role, and prevents emitting misleading events. The pattern is now consistent across `removeAdmin()`, `removeManager()`, and `removeOperator()`.

---

### QVB-26: Generic Error Usage In `proposeAction()` Masks Different Failure Conditions

| | |
|---|---|
| **Category** | Coding Style |
| **Severity** | Minor |
| **Location** | Lines 817~822 |
| **Status** | Resolved |

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

**Solution Implemented:**
Added 3 new custom errors to `IQubicBridge.sol` and replaced generic errors in `proposeAction()`:
- `InvalidDataLength()` — when `data.length < 4` (calldata too short to contain a function selector)
- `FunctionNotRegistered()` — when the function selector is not in the registered functions mapping
- `RoleMismatch()` — when the provided `roleRequired` doesn't match the registered role for that function

The existing `UnauthorizedRole()` error is still used for the two cases where it's semantically correct: when the caller lacks the required role, and when an invalid role type is provided.

---

## Informational

### QVB-27: Inconsistent Documentation And Implementation

| | |
|---|---|
| **Category** | Inconsistency |
| **Severity** | Informational |
| **Location** | Lines 61, 927~928, 1063 |
| **Status** | Resolved |

**Description:**
Several inconsistencies between code comments, NatSpec documentation, and actual implementation:

1. **Obsolete Comments**: `feeRecipient` is not actually constant.
2. **Incorrect NatSpec**: `getAdmins()` documentation states "Gets all admins (excluding the contract itself)" but the implementation returns all role members including the contract itself.
3. **Misleading Documentation**: `cancelProposal()` NatSpec says "only proposer can cancel" but the code allows both the proposer AND any admin to cancel.
4. **Missing Documentation**: Several functions lack proper NatSpec documentation.

**Recommendation:**
1. Remove obsolete comments and clean up code.
2. Update all NatSpec documentation to accurately reflect the implementation.

**Solution Implemented:**
Fixed all 3 NatSpec inconsistencies:
1. Split the "Constants" section into "Immutables" (for `token`) and "Configuration" (for mutable state like `feeRecipient`).
2. Updated `cancelProposal()` NatSpec from `"only proposer can cancel"` to `"proposer or admin can cancel"`.
3. Updated `getAdmins()` NatSpec to `"Gets all admins"` — removed the inaccurate `"excluding the contract itself"` claim.

---

### QVB-28: Missing Interface Inheritance For Contract Implementation

| | |
|---|---|
| **Category** | Coding Issue |
| **Severity** | Informational |
| **Location** | Line 9 |
| **Status** | Resolved |

**Description:**
`QubicBridge.sol` implements its functionality directly without inheriting from or implementing explicit interface contracts. This leads to:

1. Lack of explicit contract API
2. Integration difficulties for other contracts
3. Upgradeability challenges
4. Documentation gap

> Note: This finding also applies to `QubicToken.sol` (see [audit-QubicToken.md](audit-QubicToken.md)).

**Recommendation:**
Create and inherit an `IQubicBridge` interface file.

**Solution Implemented:**
`QubicBridge` now inherits from `IQubicBridge`:
```solidity
contract QubicBridge is IQubicBridge, AccessControlEnumerable, ReentrancyGuardTransient, Pausable {
```
All custom errors, events, and the `PullOrder` struct are defined in `IQubicBridge.sol` and inherited by the contract. Duplicate declarations were removed from the contract. Test files updated to reference `IQubicBridge.ErrorName` and `IQubicBridge.EventName`.

Similarly, `QubicToken` now inherits from `IQubicToken`:
```solidity
contract QubicToken is IQubicToken, ERC20, AccessControlEnumerable {
```

---

### QVB-29: Internal Function `getTransferFee()` Should Be Public Or Renamed With Underscore

| | |
|---|---|
| **Category** | Coding Style / Inconsistency |
| **Severity** | Informational |
| **Location** | Line 1037 |
| **Status** | Resolved |

**Description:**
The `getTransferFee()` function is marked as `internal` but follows naming conventions typically used for public/external functions. Solidity convention uses leading underscore (`_`) for internal/private functions. Other internal helpers like `_removePendingProposal()` correctly use underscore prefix.

The fee calculation logic could be useful externally for:
- Users to preview fees before creating orders
- Frontends to display expected fees
- Monitoring tools to verify fee calculations

**Recommendation:**
Either:
1. Make it `public` (preferred if external access is useful for fee previews).
2. Rename to `_getTransferFee()` if it should remain internal-only.

**Solution Implemented:**
Renamed `getTransferFee` to `_getTransferFee` to follow Solidity naming conventions for internal functions. Updated all 3 internal call sites (`confirmOrder`, `revertOrder`, `executeOrder`). The function remains `internal view` as the fee calculation depends on the contract's `baseFee` state and is primarily used within bridge operations.

---

## Optimizations

### QVB-05: Redundant Validation In `isQubicAddress()` Function

| | |
|---|---|
| **Location** | Lines 1161~1162 |
| **Status** | Resolved |

**Description:**
The `isQubicAddress()` function contains a redundant `allZeros` check that is already covered by the `allSame` validation.

**Recommendation:**
Remove the redundant `allZeros` check.

**Solution Implemented:**
Removed the `allZeros` variable and its associated logic from `isQubicAddress()`. The `allSame` check already covers the all-zeros case (since all zeros is a subset of all-same-character). The comment was updated to clarify: `"Check that address is not all same character (covers all-zeros case)"`.
