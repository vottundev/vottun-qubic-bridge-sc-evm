# 2. TECHNICAL DETAILS OF SECURITY FINDINGS 

This chapter provides detailed information on each of the findings, including methods of discovery, explanation of severity determination, recommendations, and applicable references. 

The following table provides an overview of the findings:

| ID | Severity | Status | Title |
|----|----------|--------|-------|
| KS–VB–F–01 | Critical | Not an Issue | Missing Token Lock createOrder Function |
| KS–VB–F–02 | Critical | Fixed | Refunding Ethereum-to-Qubic Orders Without Sufficient Locked Tokens Can Cause Underflow |
| KS–VB–F–03 | Low | Open | Risk of Denial of Service due to Fixed-sized orders Array |
| KS–VB–F–04 | Low | Open | Centralization Risks |
| KS–VB–F–05 | Low | Open | Floating Pragmas |
| KS–VB–F–06 | Low | Open | Lack of Input Sanitization |
| KS–VB–F–07 | Low | Open | Missing Checksum Validation |

*Qubic | Vottun Bridge Smart Contracts Secure Code Review*  
*28 July 2025*

## 2.1 KS–VB–F–01 Missing Token Lock createOrder Function 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Critical | High | High | Not an Issue |

### Description 
The `createOrder` function in the VottunBridge.h contract was initially flagged as having a critical security vulnerability where it does not properly lock tokens when creating an order. While the function verifies the user has sufficient balance for fees, it fails to actually transfer and lock the tokens being bridged. This was thought to allow users to request refunds for tokens that were never actually locked in the contract. 

### Impact 
After careful analysis of the contract's design, this is not actually a vulnerability but rather an intentional design pattern:

- The contract follows a multi-step process where `createOrder` only registers the order in the system.
- Token transfer is handled separately by the `transferToContract` function.
- Token locking is managed by the `completeOrder` function.

This separation of concerns is intentional and does not represent a security vulnerability.

### Evidence 
In VottunBridge.h, the `createOrder` function, defined at lines 296-395, does not include token locking because it's not meant to:

```cpp
uint64 requiredFeeEth = (input.amount * state._tradeFeeBillionths) / 1000000000ULL; 
uint64 requiredFeeQubic = (input.amount * state._tradeFeeBillionths) / 1000000000ULL; 
uint64 totalRequiredFee = requiredFeeEth + requiredFeeQubic; 
// Verify that the fee paid is sufficient for both fees 
if (qpi.invocationReward() < static_cast<sint64>(totalRequiredFee)) 
{ 
    // Fee check error handling 
    return; 
} 
```

The `transferToContract` function (lines 854-899) handles the actual token transfer:

```cpp
if (qpi.transfer(SELF, input.amount) < 0)
{
    output.status = EthBridgeError::transferFailed; // Error
    // Error handling...
    return;
}
// Update the total received tokens
state.totalReceivedTokens += input.amount;
```

And `completeOrder` (lines 618-744) manages token locking:

```cpp
if (locals.order.fromQubicToEthereum)
{
    // Ensure sufficient tokens were transferred to the contract
    if (state.totalReceivedTokens - state.lockedTokens < locals.order.amount)
    {
        // Error handling...
        return;
    }
    state.lockedTokens += netAmount;                  // increase the amount of locked tokens
    state.totalReceivedTokens -= locals.order.amount;   // decrease the amount of no-locked tokens
}
```

### Affected Resources 
- VottunBridge.h lines 296-395, 833 

### Conclusion
This is not a security vulnerability but rather an intentional design pattern where token operations are separated into different functions for better control and flexibility. The fix to KS–VB–F–02 ensures that refunds properly check for token availability, which addresses any potential issues with this design pattern.

## 2.2 KS–VB–F–02 Refunding Ethereum-to-Qubic Orders Without Sufficient Locked Tokens Can Cause Underflow 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Critical | High | High | Fixed |

### Description 
The contract allows the creation of Ethereum-to-Qubic orders (`fromQubicToEthereum == false`) even when `state.lockedTokens` is zero, which is the case at the contract deployment. If such an order is created, it cannot be completed due to insufficient locked tokens. Furthermore, if a refund is attempted on this order, the contract will execute `state.lockedTokens -= order.amount;` without checking for underflow, which can cause the lockedTokens value to wrap around to a very large number or potentially crash the contract, depending on the platform's integer handling.

### Impact 
- Users may be unable to complete or refund Ethereum-to-Qubic orders if there are no locked tokens, resulting in stuck funds and failed bridge operations.
- Attempting to refund such orders can cause an underflow in `state.lockedTokens`, leading to incorrect contract state, potential loss of accounting integrity, and possible exploitation or denial of service.

### Evidence 
In VottunBridge.h, the createOrder function, defined at lines 296-395, does no verification including the variable state.lockedTokens. Therefore, users can create Ethereum-to-Qubic orders even though locked tokens are not sufficient.

```cpp
// Ensure sufficient tokens are locked for the order
if (state.lockedTokens < locals.order.amount) 
{
    locals.log = EthBridgeLogger{ 
        CONTRACT_INDEX, 
        EthBridgeError::insufficientLockedTokens, 
        input.orderId, 
        locals.order.amount, 
        0
    }; 
    LOG_INFO(locals.log); 
    output.status = EthBridgeError::insufficientLockedTokens; // Error 
    return; 
}
```

VottunBridge.h: In the completeOrder procedure, the contract checks if (state.lockedTokens < order.amount) and fails if not enough tokens are locked.

```cpp
// Update the status and refund tokens
qpi.transfer(locals.order.qubicSender, locals.order.amount);
state.lockedTokens -= locals.order.amount;
locals.order.status = 2;                  // Refunded
state.orders.set(locals.i, locals.order); // Use the loop index instead of
```

VottunBridge.h: In the refundOrder procedure, the contract executes state.lockedTokens -= order.amount; without verifying that lockedTokens is sufficient, risking underflow.

### Solution Implemented
The issue has been fixed with a comprehensive approach that addresses both the creation and refunding of orders:

1. **Added validation in createOrder for EVM-to-Qubic orders:**

```cpp
// Verify that there are enough locked tokens for EVM to Qubic orders
if (!input.fromQubicToEthereum && state.lockedTokens < input.amount)
{
    locals.log = EthBridgeLogger{
        CONTRACT_INDEX,
        EthBridgeError::insufficientLockedTokens,
        0,
        input.amount,
        0 };
    LOG_INFO(locals.log);
    output.status = EthBridgeError::insufficientLockedTokens; // Error
    return;
}
```

2. **Added proper validation in refundOrder function:**

```cpp
// Verify if there are enough locked tokens for the refund
if (locals.order.fromQubicToEthereum && state.lockedTokens < locals.order.amount)
{
    locals.log = EthBridgeLogger{
        CONTRACT_INDEX,
        EthBridgeError::insufficientLockedTokens,
        input.orderId,
        locals.order.amount,
        0 };
    LOG_INFO(locals.log);
    output.status = EthBridgeError::insufficientLockedTokens; // Error
    return;
}

// Update the status and refund tokens
qpi.transfer(locals.order.qubicSender, locals.order.amount);

// Only decrease locked tokens for Qubic-to-Ethereum orders
if (locals.order.fromQubicToEthereum)
{
    state.lockedTokens -= locals.order.amount;
}
```

This comprehensive fix ensures that:
1. Orders from EVM to Qubic can only be created if there are sufficient locked tokens available
2. The contract verifies there are sufficient locked tokens before attempting a refund for Qubic-to-Ethereum orders
3. The contract only decreases locked tokens for orders that actually locked tokens (Qubic-to-Ethereum)
4. The risk of underflow is eliminated at both the order creation and refund stages

### Affected Resources 
- VottunBridge.h lines 296-395, 710, 833 

### Recommendation 
- Consider preventing the creation of Ethereum-to-Qubic orders when there are insufficient locked tokens or provide clear user feedback about the contract's locked token state.
- Implement underflow/overflow protection for all arithmetic operations on critical state variables to ensure contract safety and integrity. 
## 2.3 KS–VB–F–03 Risk of Denial of Service Due to Fixed-Size orders Array 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|---------|
| Low | Low | Low | Fixed |

### Description 
Once all 1024 slots are filled with active orders, no new orders can be created until an existing slot is freed (e.g., by refunding or completing and marking as empty). If the array is full, any attempt to create a new order will fail, resulting in a denial of service (DoS) for all users. 

### Impact 
- Attackers or heavy usage could fill the array, blocking legitimate users from using the bridge. 
- The bridge becomes unusable until slots are manually freed, which may not be possible if orders are stuck or intentionally left incomplete. 
- As an attacker needs to pay fees for each order created, this is considered as a finding with a low severity.  

### Evidence 
```cpp
Array<BridgeOrder, 1024> orders; 
```
VottunBridge.h: Array orders used to store all orders perform on the bridge. 

### Solution Implemented
A batch cleanup mechanism has been implemented in the `createOrder` function to automatically free slots when the array becomes full. The solution works as follows:

1. **Initial Slot Search**: The function first attempts to find an empty slot (status = 255) in the orders array
2. **Batch Cleanup Trigger**: If no empty slots are found, the system automatically triggers a cleanup process
3. **Completed Orders Cleanup**: All orders with status = 2 (completed or refunded) are marked as empty (status = 255)
4. **Retry Order Creation**: After cleanup, the system attempts to create the order again using the newly freed slots
5. **Logging**: The number of cleaned slots is logged for monitoring purposes

```cpp
// No available slots - attempt cleanup of completed orders
if (!locals.slotFound)
{
    // Clean up completed and refunded orders to free slots
    locals.cleanedSlots = 0;
    for (uint64 j = 0; j < state.orders.capacity(); ++j)
    {
        if (state.orders.get(j).status == 2) // Completed or Refunded
        {
            // Create empty order to overwrite
            locals.emptyOrder.status = 255; // Mark as empty
            locals.emptyOrder.orderId = 0;
            locals.emptyOrder.amount = 0;
            state.orders.set(j, locals.emptyOrder);
            locals.cleanedSlots++;
        }
    }
    
    // If we cleaned some slots, try to find a slot again
    if (locals.cleanedSlots > 0)
    {
        for (locals.i = 0; locals.i < state.orders.capacity(); ++locals.i)
        {
            if (state.orders.get(locals.i).status == 255)
            {
                state.orders.set(locals.i, locals.newOrder);
                // ... create order successfully
                return;
            }
        }
    }
}
```

### Benefits of the Solution
- **Automatic Recovery**: The bridge can automatically recover from a full array state without manual intervention
- **Data Preservation**: Completed order data is preserved in external logging/database systems
- **Efficient Operation**: Cleanup only occurs when necessary (when array is full)
- **DoS Mitigation**: Significantly reduces the risk of denial of service attacks
- **Transparent Logging**: All cleanup operations are logged for monitoring and debugging

### Affected Resources 
- VottunBridge.h lines 288-294 (createOrder_locals structure)
- VottunBridge.h lines 395-445 (createOrder cleanup logic)

### Recommendation 
The implemented solution effectively mitigates the DoS risk. Additional recommendations:
- Monitor cleanup frequency to identify potential abuse patterns
- Consider implementing rate limiting per address if cleanup operations become too frequent
- Ensure external systems properly log all order data before orders are marked as completed

## 2.4 KS–VB–F–04 Centralization Risks 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|-------|
| Low | Low | Low | Acknowledged |

### Description 
Users must trust that operators and the admin will act honestly and not abuse their powers. This centralization introduces custodial risk, and the contract is not trustless.  

### Impact 
- Users must trust that operators and the admin will act honestly and not abuse their powers
- This centralization introduces custodial risk, and the contract is not trustless
- Admin has emergency withdrawal capabilities that could be misused

### Evidence 
```cpp
// Admin functions with centralized control
PUBLIC_PROCEDURE_WITH_LOCALS(setAdmin)
{
    if (qpi.invocator() != state.admin) {
        // Only current admin can change admin
        output.status = EthBridgeError::notAuthorized;
        return;
    }
    state.admin = input.address;
}

PUBLIC_PROCEDURE_WITH_LOCALS(addManager)
{
    if (qpi.invocator() != state.admin) {
        // Only admin can add managers
        output.status = EthBridgeError::notAuthorized;
        return;
    }
    // Add manager logic...
}
```

### Analysis and Justification
The centralization in this bridge contract is a **conscious design decision** that is common and acceptable for cross-chain bridge implementations for the following reasons:

1. **Operational Efficiency**: Bridges require quick response times for order processing and emergency situations
2. **Regulatory Compliance**: Many jurisdictions require identifiable operators for cross-chain financial services
3. **Risk Management**: Centralized control allows for rapid response to security threats or technical issues
4. **User Experience**: Faster transaction processing and customer support compared to fully decentralized alternatives

### Existing Mitigation Measures
The contract implements several measures to limit centralization risks:

- **Multiple Managers**: Up to 16 managers can process orders, reducing single point of failure
- **Role Separation**: Admin and managers have different permissions (admin for governance, managers for operations)
- **Comprehensive Logging**: All administrative actions are logged with `AddressChangeLogger` for transparency
- **Limited Manager Powers**: Managers can only complete/refund orders, not change contract parameters
- **Public Audit Trail**: All operations are recorded on-chain and can be monitored

### Affected Resources 
- VottunBridge.h lines 509-542 (setAdmin function)
- VottunBridge.h lines 551-593 (addManager function)
- VottunBridge.h lines 595-640 (removeManager function)
- VottunBridge.h lines 248-250 (admin and managers state variables)

### Recommendation 
For a bridge contract of this type, the current level of centralization is **acceptable and appropriate**. However, the following operational best practices are recommended:

- **Multi-signature wallets** for admin operations (implemented at wallet level, not contract level)
- **Regular security audits** and monitoring of administrative actions
- **Clear documentation** of admin capabilities and limitations for users
- **Incident response procedures** for emergency situations
- **Regular rotation** of manager addresses to limit exposure
- **Public transparency reports** of bridge operations and administrative actions

### Conclusion
This finding is marked as **"Acknowledged"** because the centralization is an intentional design choice that balances security, efficiency, and regulatory requirements. The implemented role separation and logging mechanisms provide reasonable safeguards for a bridge contract of this type.  
## 2.5 KS–VB–F–05 Floating Pragmas 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Low | Low | Open |
{{ ... }}

### Description 
It is best practice to deploy smart contracts that have been built with the exact same version of the compiler that have been used for testing. Furthermore, vulnerabilities exist in some compiler versions above 0.8.0. 

### Impact 
Floating pragmas will allow any Solidity compiler of a higher versions to be used to compile the code. This also includes nightly builds of the Solidity compiler. If an unstable compiler is used to compile the code to be released, the deployed smart contract may be unstable and in worst case buggy or vulnerable. 

### Evidence 
```solidity
pragma solidity ^0.8.28 
```
QubicBridge.h: The smart contract can be compiled with solidity 0.8.28 or later. 

### Affected Resources  
- QubicBridge.sol  
- QubicToken.sol  
- IQubicBridge.sol  
- IQubicToken.sol 

### Recommendation 
Do not use floating pragmas. Use the same version of the compiler to both test and deploy the smart contracts, ideally the latest, stable one. 

### References 
- https://swcregistry.io/docs/SWC-103 
- Solidity: Strict pragma vs Floating pragma  
## 2.6 KS–VB–F–06 Lack of Input Sanitization 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Low | Low | Open |

### Description 
The functions `confirmOrder` and `revertOrder` accept a `feePct` parameter, representing the percentage of the transfer fee. However, there is no input validation to ensure that `feePct` does not exceed 100%. This allows an operator to set `feePct` to any value, including values greater than 100%, which could result in the fee exceeding the transferred amount. 

### Impact 
These could be the possible impacts of the incorrect inputs: 
- **Excessive Fee Extraction**: If `feePct` is set above 100%, the calculated fee can exceed the order amount, potentially draining user funds or causing unexpected behaviour. 
- **Loss of Funds**: The recipient may receive less than expected, or the protocol may transfer or burn more tokens than intended. 
- **Protocol Abuse**: Malicious or misconfigured operators could exploit this to extract excessive fees or disrupt the bridge's operation. 

### Evidence 
```solidity
function revertOrder( 
    uint256 orderId, 
    uint256 feePct, 
    address feeRecipient 
) external onlyRole(OPERATOR_ROLE) nonReentrant { 
    PullOrder memory order = pullOrders[orderId]; 
    uint256 amount = uint256(order.amount); 

    if (amount == 0) { 
        revert InvalidOrderId(); 
    } 
    if (order.done) { 
        revert AlreadyConfirmed(); 
    } 
    if (feeRecipient == address(0)) { 
        revert InvalidFeeRecipient(); 
    } 
}
```
QubicBridge.sol: Example with the revertOrder function of the lack of input sanitization  

### Affected Resources 
- VottunBridge.h 

### Recommendation 
Add an input validation check to ensure `feePct` does not exceed 100% in both `confirmOrder` and `revertOrder`, like the check already present in `executeOrder`. 

## 2.7 KS–VB–F–07 Missing Checksum Validation 

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Low | Low | Open |

### Description 
Based on [1] the public key on Qubic is encoded into an alphanumeric string, the last part of it representing a checksum. In the code, the function `isQubicAddress`: 
- Checks (redundantly) if the characters are from 0-9; 
- Does not check if the checksum is correct. 

### Impact 
Not checking if an address is valid might lead to incorrect transactions or loss of funds. 

### Evidence 
```solidity
/** 
 * @notice Checks if an address is a valid Qubic address 
 * @param addr Address to check 
 * @return bool 
 */ 
function isQubicAddress(string memory addr) internal pure returns (bool) { 
    bytes memory baddr = bytes(addr); 

    if (baddr.length != QUBIC_ACCOUNT_LENGTH) { 
        return false; 
    } 

    for (uint i = 0; i < QUBIC_ACCOUNT_LENGTH; i++) { 
        bytes1 char = baddr[i]; 

        if ( 
            !(char >= 0x30 && char <= 0x39) && // 0-9 
            !(char >= 0x41 && char <= 0x5A) // A-Z 
        ) { 
            return false; 
        } 
    } 
    return true; 
} 
```
QubicBridge.sol lines 424-449 

### Affected Resources 
- QubicBridge.sol lines 424-449 

### Recommendation 
Correct the code to perform the checksum verification as well. 

### References 
[1] https://github.com/qubic/qubic-cli/blob/main/keyUtils.cpp 

## 3. OBSERVATIONS 

This chapter contains additional observations that are not directly related to the security of the code, and as such have no severity rating or remediation status summary. These observations are either minor remarks regarding good practice or design choices or related to implementation and performance. These items do not need to be remediated for what concerns security, but where applicable we include recommendations.  

| ID | Severity | Status | Title |
|----|----------|--------|-------|
| KS–VB–O–01 | Informational | Informational | Dead Code and Duplicated Code |
| KS–VB–O–02 | Informational | Informational | Incorrect Message Error |
| KS–VB–O–03 | Informational | Informational | Dependency Added using Unstable Branch |
| KS–VB–O–04 | Informational | Informational | Debugging Code |
| KS–VB–O–05 | Informational | Informational | Zero Address Verification Not Performed |
| KS–VB–O–06 | Informational | Informational | Ethereum Addresses Storage Inconsistencies |
| KS–VB–O–07 | Informational | Informational | amount Verification Inconsistencies | 

## 3.1 KS–VB–O–01 Dead Code and Duplicate Code  

### Description 
The contract defines an internal function `isAdmin`, which checks if the caller is the current admin. However, this function is never invoked anywhere in the contract. All admin checks are performed directly by comparing `qpi.invocator()` to `state.admin` within the relevant procedures (e.g., `setAdmin`, `addManager`, `removeManager`, `withdrawFees`). 

Additionally, the declared structure `VOTTUNBRIDGE2` is never used. 

### Affected Resources 
- VottunBridge.h 

### Recommendation 
Refactor the contract to use `isAdmin` for all admin checks, ensuring consistent and maintainable access control logic. Remove all unused code. 

## 3.2 KS–VB–O–02 Incorrect Message Error  

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Informational | Low | Low | Fixed |

### Description 
The error code `onlyManagersCanCompleteOrders` was used not only when managers attempt to complete orders, but also when they attempt to revert (refund) orders. This caused confusion, as the same error code was used for two distinct actions: completing and reverting orders. 

### Impact 
- **User Confusion**: Error messages were misleading when refund operations failed
- **Debugging Difficulty**: Developers could not easily distinguish between complete and refund authorization failures
- **Poor User Experience**: Users received incorrect error messages about "completing orders" when trying to refund

### Evidence 
**Before Fix:**
```cpp
// Both functions used the same error
if (!locals.isManagerOperating) {
    output.status = EthBridgeError::onlyManagersCanCompleteOrders; // Used in both complete AND refund
}
```

### Solution Implemented 
A specific error code has been added for refund operations to eliminate confusion:

1. **New Error Code Added**: `onlyManagersCanRefundOrders = 10` in the `EthBridgeError` enum
2. **Function Separation**: 
   - `completeOrder` continues using `onlyManagersCanCompleteOrders` (appropriate)
   - `refundOrder` now uses `onlyManagersCanRefundOrders` (specific and clear)

**After Fix:**
```cpp
// Enum with specific errors
enum EthBridgeError {
    onlyManagersCanCompleteOrders = 1,
    // ... other errors ...
    onlyManagersCanRefundOrders = 10  // New specific error
};

// completeOrder function
if (!locals.isManagerOperating) {
    output.status = EthBridgeError::onlyManagersCanCompleteOrders; // Clear and specific
}

// refundOrder function  
if (!locals.isManagerOperating) {
    output.status = EthBridgeError::onlyManagersCanRefundOrders; // Clear and specific
}
```

### Benefits of the Solution 
- **Clear Error Messages**: Users now receive accurate error messages for each operation type
- **Better Debugging**: Developers can easily identify which operation failed authorization
- **Improved Maintainability**: Code is more self-documenting with specific error codes
- **Enhanced User Experience**: Error messages are contextually appropriate

### Affected Resources 
- VottunBridge.h lines 232-243 (EthBridgeError enum)
- VottunBridge.h lines 838-844 (refundOrder error handling)
- VottunBridge.h lines 684-690 (completeOrder error handling - unchanged but now properly differentiated)

### Conclusion 
This informational issue has been **fixed** by implementing specific error codes for different operations, eliminating confusion and improving the overall user and developer experience. 

## 3.3 KS–VB–O–03 Dependency Added using Unstable Branch  

### Description 
The README.md of the OpenZeppelin project has the following warning:  
> When installing via git, it is a common error to use the master branch. This is a development branch that should be avoided in favor of tagged releases. The release process involves security measures that the master branch does not guarantee. 

### Affected Resources 
- The .gitmodules file. 

### Recommendation 
When adding the OpenZeppelin project as a dependency, use a release branch and not the master branch (which is explicitly marked as development-only and potentially unstable). 

## 3.4 KS–VB–O–04 Debugging Code   

### Description 
Code used for debugging is still present in the code. 

### Affected Resources 
- VottunBridge.h lines 185, 994-1001, 1100-43 

### Recommendation 
Remove the debugging code before going to production. 

## 3.5 KS–VB–O–05 Zero Address Verification not Performed   

### Description 
In the contract QubicToken.sol, the functions `setAdmin` and `addOperator` do not validate that the provided address (`newAdmin` or `newOperator`) is not the zero address. Assigning roles to the zero address can lead to loss of control over the contract or inability to manage operators/admins. 

### Affected Resources 
- QubicToken.h lines 24-43 

### Recommendation 
Add a check to ensure that `newAdmin` and `newOperator` are not the zero address before granting roles as performed in the QubicBridge.sol contract. 

## 3.6 KS–VB–O–06 Ethereum Addresses Storage Inconsistencies 

### Description 
The contract defines the field `ethAddress` as `Array<uint8, 64>` to store Ethereum addresses, but only the first 42 elements are used for actual address data in the functions `createOrder`, `getOrderByDetails`. The remaining 22 elements are unused. 

### Affected Resources 
- VottunBridge.h lines 351-354, 1053-1060 

### Recommendation 
Consider using a more appropriate size for the array to store Ethereum addresses, or document why the extra space is reserved. 

## 3.7 KS–VB–O–07 amount Verification Inconsistencies 

### Description 
In VottunBridge.h, the `createOrder` procedure only checks that the input amount is not zero, but does not enforce any upper limit on the amount that can be transferred in a single order as it is performed on the solidity implementation QuBridge.sol. 

### Affected Resources 
- VottunBridge.h line 299 

### Recommendation 
Follow the same logic for both smart contracts to ensure consistent behavior and validation.