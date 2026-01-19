# QubicBridge Multisig Testing Guide - Base Sepolia Explorer

## Important: Bridge Setup Required

⚠️ **Before testing, ensure the bridge is set up correctly:**

1. **Bridge must be added as operator in the token contract** (similar to approve, but for mint/burn permissions)
   - Token contract: `0x5438615E84178C951C0EB84Ec9Af1045eA2A7C78`
   - Bridge address: `0x50B0A6391BB06cc0C7a228D41352EE91d496aE78`
   - Action: Call `addOperator(0x50B0A6391BB06cc0C7a228D41352EE91d496aE78)` on the token contract
   - Required by: Admin of the token contract
   - This is like an "approve" but for mint/burn permissions - the bridge needs this role to mint tokens when users cross from Qubic to EVM

**Why?** The bridge needs `OPERATOR_ROLE` in the token to be able to:
- `mint()` tokens via `executeOrder()` (Qubic → Ethereum)
- `burn()` tokens via `confirmOrder()` (Ethereum → Qubic)

**To check if bridge is already operator:**
- Go to token contract → "Read Contract" → `getOperators()`
- If bridge address is in the list, you're good. If not, it needs to be added.

---

## Test Wallets

Test wallets for multisig testing are provided in `test-wallets.json`. This file contains:

**Admin Wallets** (3 wallets):
- **Admin 1**: `0xDb29Aedd947eBa1560dd31CffEcf63bbB817aB4A`
- **Admin 2**: `0x7002b4761B7B836b20F07e680b5B95c755197102`
- **Admin 3**: `0xd661A118E93E24608C2c4768e232E38F45F1CA33`

**Manager Wallets** (2 wallets):
- **Manager 1**: `0xcbEe35eCAaBbff134f9a236E00DdF14963D2Ed24`
- **Manager 2**: `0xB2CE6EC2E25984397a51509aB57303FE4aDf667A`

**Operator Wallets** (1 wallet):
- **Operator 1**: `0xad6719141371952d926f5f2d72Ed6bc636d77C3a`

Each wallet in `test-wallets.json` includes:
- Address
- Private key
- Seed phrase (mnemonic)

**Note**: These wallets are for testing purposes. To use them with the deployed contract, you'll need to first add them as admins/managers/operators via multisig proposals using the original deployment wallets.

Import these wallets to MetaMask using either the private key or seed phrase to test the multisig workflow. You'll need to switch between wallets when testing approval workflows (e.g., Admin 1 proposes → Admin 2 approves → Admin 3 approves).

---

## Contract Information

**Contract Address**: `0x50B0A6391BB06cc0C7a228D41352EE91d496aE78`  
**Network**: Base Sepolia (Chain ID: 84532)  
**Explorer**: https://sepolia.basescan.org/address/0x50b0a6391bb06cc0c7a228d41352ee91d496ae78

**Deployment Configuration**:
- Admin 1: `0x464800222D2AB38F696f0f74fe6A9fA5A2693E12`
- Admin 2: `0x0e60B83F83c5d2684acE779dea8A957e91D02475`
- Admin 3: `0x090378a9c80c5E1Ced85e56B2128c1e514E75357`
- Admin Threshold: `2` (2-of-3 multisig)
- Manager Threshold: `2` (2-of-3 multisig)
- Fee Recipient: `0x090378a9c80c5E1Ced85e56B2128c1e514E75357`

**Role Constants**:
- `DEFAULT_ADMIN_ROLE`: `0x0000000000000000000000000000000000000000000000000000000000000000`
- `MANAGER_ROLE`: `0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08`
- `OPERATOR_ROLE`: `0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929`

---

## Function Selectors Reference

### Admin Functions
- `addAdmin(address)`: `0x70480275`
- `removeAdmin(address)`: `0x1785f53c`
- `addManager(address)`: `0x2d06177a`
- `removeManager(address)`: `0xac18de43`
- `setBaseFee(uint256)`: `0x46860698`
- `setFeeRecipient(address)`: `0xe74b981b`
- `setAdminThreshold(uint256)`: `0x5af28cf9`
- `setManagerThreshold(uint256)`: `0x4fdfb1ad`
- `emergencyPause()`: `0x51858e27`
- `emergencyUnpause()`: `0x4a4e3bd5`
- `emergencyTokenWithdraw(address,address,uint256)`: `0xfef860b8`
- `emergencyEtherWithdraw(address)`: `0x77964ad1`

### Manager Functions
- `addOperator(address)`: `0x9870d7fe`
- `removeOperator(address)`: `0xac8a584a`

### Multisig Functions
- `proposeAction(bytes,bytes32)`: `0xf4cf8576`
- `approveProposal(bytes32)`: `0xf20b5b2c`
- `executeProposal(bytes32)`: `0x980ff6c6`
- `cancelProposal(bytes32)`: `0x37376ca8`

---

## Testing Workflow

All admin and manager functions require a 3-step process:
1. **Propose**: Create a proposal with encoded function data
2. **Approve**: Get required approvals (2-of-3 for admin, 2-of-3 for manager)
3. **Execute**: Execute the proposal once threshold is met

---

## READ Contract Functions

### 1. Check Current Configuration

**Function**: `adminThreshold()`
- **Purpose**: Get current admin approval threshold
- **Parameters**: None
- **Expected Result**: `2` (uint256)

**Function**: `managerThreshold()`
- **Purpose**: Get current manager approval threshold
- **Parameters**: None
- **Expected Result**: `2` (uint256)

**Function**: `baseFee()`
- **Purpose**: Get current base fee in basis points
- **Parameters**: None
- **Expected Result**: `5` (0.05%)

**Function**: `feeRecipient()`
- **Purpose**: Get current fee recipient address
- **Parameters**: None
- **Expected Result**: `0x090378a9c80c5E1Ced85e56B2128c1e514E75357`

**Function**: `getAdmins(uint256 index)`
- **Purpose**: Get admin address at index
- **Parameters**: `index` (uint256) - 0, 1, or 2
- **Expected Results**: 
  - `0`: `0x464800222D2AB38F696f0f74fe6A9fA5A2693E12`
  - `1`: `0x0e60B83F83c5d2684acE779dea8A957e91D02475`
  - `2`: `0x090378a9c80c5E1Ced85e56B2128c1e514E75357`

### 2. Check Proposal Status

**Function**: `getPendingProposals()`
- **Purpose**: Get all pending proposal IDs
- **Parameters**: None
- **Returns**: Array of `bytes32` proposal IDs

**Function**: `getProposal(bytes32 proposalId)`
- **Purpose**: Get full proposal details
- **Parameters**: `proposalId` (bytes32) - Proposal ID to query
- **Returns**: 
  - `proposer` (address)
  - `data` (bytes)
  - `approvalCount` (uint256)
  - `executed` (bool)
  - `createdAt` (uint256)
  - `roleRequired` (bytes32)

**Function**: `hasApprovedProposal(bytes32 proposalId, address account)`
- **Purpose**: Check if an address has approved a proposal
- **Parameters**: 
  - `proposalId` (bytes32)
  - `account` (address)
- **Returns**: `true` or `false`

**Function**: `hasRole(bytes32 role, address account)`
- **Purpose**: Check if address has a specific role
- **Parameters**:
  - `role`: `0x0000000000000000000000000000000000000000000000000000000000000000` (admin) or `0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08` (manager)
  - `account` (address)
- **Returns**: `true` or `false`

---

## WRITE Contract Functions

### Creating a Proposal

All proposals are created using `proposeAction(bytes data, bytes32 roleRequired)`.

**Important**: The `data` parameter must be the encoded function call, including the 4-byte function selector.

#### How to Encode Data for `proposeAction`

The `data` field must be:
```
function_selector (4 bytes) + encoded_parameters (32 bytes each)
```

**Example Encodings**:

1. **`emergencyPause()`** (no parameters):
   - Selector: `0x51858e27`
   - Data: `0x51858e27`

2. **`setBaseFee(uint256)`**:
   - Selector: `0x46860698`
   - Parameter: `300` (3%) = `0x000000000000000000000000000000000000000000000000000000000000012c`
   - Data: `0x46860698000000000000000000000000000000000000000000000000000000000000012c`

3. **`setFeeRecipient(address)`**:
   - Selector: `0xe74b981b`
   - Parameter: `0x1234567890123456789012345678901234567890`
   - Data: `0xe74b981b0000000000000000000000001234567890123456789012345678901234567890`

4. **`addManager(address)`**:
   - Selector: `0x2d06177a`
   - Parameter: `0x1234567890123456789012345678901234567890`
   - Data: `0x2d06177a0000000000000000000000001234567890123456789012345678901234567890`

5. **`emergencyTokenWithdraw(address,address,uint256)`**:
   - Selector: `0xfef860b8`
   - Parameters:
     - Token: `0x1111111111111111111111111111111111111111`
     - Recipient: `0x2222222222222222222222222222222222222222`
     - Amount: `1000000000000000000` (1 token with 18 decimals)
   - Data: `0xfef860b800000000000000000000000011111111111111111111111111111111111111110000000000000000000000002222222222222222222222222222222222222222000000000000000000000000000000000000000000000000000de0b6b3a7640000`

---

## Testing Examples

### Example 1: Change Base Fee (Admin Function)

#### Step 1: Create Proposal

**Function**: `proposeAction(bytes data, bytes32 roleRequired)`

**Parameters**:
- `data`: `0x468606980000000000000000000000000000000000000000000000000000000000000300`
  - This encodes `setBaseFee(768)` (7.68%)
- `roleRequired`: `0x0000000000000000000000000000000000000000000000000000000000000000` (DEFAULT_ADMIN_ROLE)

**Connect Wallet**: Use Admin 1 wallet (`0x464800222D2AB38F696f0f74fe6A9fA5A2693E12`)

**Result**: Transaction will emit `ProposalCreated` event with `proposalId` (bytes32)

#### Step 2: Get Proposal ID

After transaction confirms, check the transaction logs or use:
- `getPendingProposals()` - The new proposal ID will be in the array

#### Step 3: Approve Proposal (Admin 2)

**Function**: `approveProposal(bytes32 proposalId)`

**Parameters**:
- `proposalId`: Copy from Step 2 (bytes32)

**Connect Wallet**: Switch to Admin 2 wallet (`0x0e60B83F83c5d2684acE779dea8A957e91D02475`)

**Result**: `approvalCount` increases to 1

#### Step 4: Approve Proposal (Admin 3)

**Function**: `approveProposal(bytes32 proposalId)`

**Parameters**:
- `proposalId`: Same as Step 3

**Connect Wallet**: Switch to Admin 3 wallet (`0x090378a9c80c5E1Ced85e56B2128c1e514E75357`)

**Result**: `approvalCount` increases to 2 (threshold met)

#### Step 5: Execute Proposal

**Function**: `executeProposal(bytes32 proposalId)`

**Parameters**:
- `proposalId`: Same proposal ID

**Connect Wallet**: Any wallet (execution is permissionless once threshold is met)

**Result**: `baseFee()` should now return `768`

**Verify**: Use `baseFee()` in Read Contract to confirm the change

---

### Example 2: Emergency Pause (Admin Function)

#### Step 1: Create Proposal

**Function**: `proposeAction(bytes data, bytes32 roleRequired)`

**Parameters**:
- `data`: `0x51858e27`
- `roleRequired`: `0x0000000000000000000000000000000000000000000000000000000000000000`

**Connect Wallet**: Admin 1

#### Step 2-4: Approve (Admin 2 and Admin 3)

Same as Example 1, Steps 2-4

#### Step 5: Execute

**Function**: `executeProposal(bytes32 proposalId)`

**Verify**: Bridge should be paused (check `paused()` function)

---

### Example 3: Add Manager (Admin Function)

#### Step 1: Create Proposal

**Function**: `proposeAction(bytes data, bytes32 roleRequired)`

**Parameters**:
- `data`: `0x2d06177a000000000000000000000000NEWMANAGERADDRESSHERE`
  - Replace `NEWMANAGERADDRESSHERE` with actual address (40 hex chars)
- `roleRequired`: `0x0000000000000000000000000000000000000000000000000000000000000000`

**Connect Wallet**: Admin 1

#### Step 2-4: Approve (Admin 2 and Admin 3)

#### Step 5: Execute

**Verify**: New manager should have MANAGER_ROLE (check with `hasRole`)

---

### Example 4: Add Operator (Manager Function)

#### Step 1: Create Proposal

**Function**: `proposeAction(bytes data, bytes32 roleRequired)`

**Parameters**:
- `data`: `0x9870d7fe000000000000000000000000NEWOPERATORADDRESSHERE`
- `roleRequired`: `0x241ecf16d79d0f8dbfb92cbc07fe17840425976cf0667f022fe9877caa831b08` (MANAGER_ROLE)

**Connect Wallet**: Manager wallet (must have MANAGER_ROLE)

#### Step 2-4: Approve (2 Managers)

**Function**: `approveProposal(bytes32 proposalId)`

**Connect Wallet**: Manager 1, then Manager 2

#### Step 5: Execute

**Verify**: New operator should have OPERATOR_ROLE

---

## Helper Tools for Encoding

### Using Web3.js (Browser Console)

```javascript
// Encode function call
const web3 = new Web3();
const functionSignature = 'setBaseFee(uint256)';
const selector = web3.utils.keccak256(functionSignature).slice(0, 10); // First 4 bytes
const encoded = web3.eth.abi.encodeFunctionCall({
    name: 'setBaseFee',
    type: 'function',
    inputs: [{type: 'uint256', name: '_baseFee'}]
}, [300]);
console.log(encoded); // 0x46860698000000000000000000000000000000000000000000000000000000000000012c
```

### Using Ethers.js (Browser Console)

```javascript
const ethers = require('ethers');
const iface = new ethers.Interface(['function setBaseFee(uint256)']);
const encoded = iface.encodeFunctionData('setBaseFee', [300]);
console.log(encoded); // 0x46860698000000000000000000000000000000000000000000000000000000000000012c
```

### Online Tools

- **HashEx**: https://abi.hashex.org/
- **MyEtherWallet**: https://www.myetherwallet.com/tools/abi-encoder

---

## Common Issues and Solutions

### Issue: "Invalid proposal data"

**Cause**: Incorrectly encoded `data` parameter  
**Solution**: Ensure function selector is correct and parameters are properly padded to 32 bytes

### Issue: "Caller does not have required role"

**Cause**: Wallet doesn't have the role required for the proposal  
**Solution**: 
- For admin proposals: Must be admin
- For manager proposals: Must be manager

### Issue: "Proposal already executed"

**Cause**: Trying to execute a proposal that was already executed  
**Solution**: Check `getProposal(proposalId)` - `executed` field will be `true`

### Issue: "Proposal does not exist"

**Cause**: Invalid proposal ID  
**Solution**: Verify proposal ID from `getPendingProposals()` or transaction logs

### Issue: "Cannot approve twice"

**Cause**: Same wallet trying to approve twice  
**Solution**: Check `hasApprovedProposal(proposalId, address)` before approving

---

## Testing Checklist

### Admin Functions (Require 2-of-3 Approval)

- [ ] `setBaseFee` - Change base fee
- [ ] `setFeeRecipient` - Change fee recipient address
- [ ] `addAdmin` - Add new admin (if < 3 admins)
- [ ] `removeAdmin` - Remove admin
- [ ] `addManager` - Add manager
- [ ] `removeManager` - Remove manager
- [ ] `setAdminThreshold` - Change admin threshold
- [ ] `setManagerThreshold` - Change manager threshold
- [ ] `emergencyPause` - Pause bridge
- [ ] `emergencyUnpause` - Unpause bridge
- [ ] `emergencyTokenWithdraw` - Withdraw tokens
- [ ] `emergencyEtherWithdraw` - Withdraw ETH

### Manager Functions (Require 2-of-3 Approval)

- [ ] `addOperator` - Add operator
- [ ] `removeOperator` - Remove operator

### Proposal Management

- [ ] `proposeAction` - Create proposal
- [ ] `approveProposal` - Approve proposal
- [ ] `executeProposal` - Execute approved proposal
- [ ] `cancelProposal` - Cancel proposal (proposer or admin only)
- [ ] `getPendingProposals` - List all pending proposals
- [ ] `getProposal` - Get proposal details
- [ ] `hasApprovedProposal` - Check approval status

---

## Event Monitoring

All proposals emit events that can be monitored in the explorer:

### ProposalCreated
```
event ProposalCreated(bytes32 indexed proposalId, address indexed proposer, bytes data, bytes32 roleRequired);
```

### ProposalApproved
```
event ProposalApproved(bytes32 indexed proposalId, address indexed approver, uint256 approvalCount);
```

### ProposalExecuted
```
event ProposalExecuted(bytes32 indexed proposalId, address indexed executor);
```

### ProposalCancelled
```
event ProposalCancelled(bytes32 indexed proposalId, address indexed canceller);
```

**To view events**: Go to contract page → "Events" tab → Filter by event name

---

## Security Notes

1. **Double Approval Prevention**: Same address cannot approve twice (checked automatically)

2. **Role Validation**: Only admins can propose/admin actions, only managers can propose manager actions

3. **Threshold Enforcement**: Proposals cannot be executed until threshold is met

4. **Execution Permission**: Anyone can execute once threshold is met (designed for gas efficiency)

5. **Cancellation**: Only proposer or admin can cancel proposals

---

## Quick Reference: Encoding Common Functions

### No Parameters
- `emergencyPause()`: `0x51858e27`
- `emergencyUnpause()`: `0x4a4e3bd5`

### Single Address Parameter
- `setFeeRecipient(address)`: `0xe74b981b` + `000000000000000000000000` + address (40 chars)
- `addAdmin(address)`: `0x70480275` + `000000000000000000000000` + address
- `addManager(address)`: `0x2d06177a` + `000000000000000000000000` + address
- `addOperator(address)`: `0x9870d7fe` + `000000000000000000000000` + address
- `removeAdmin(address)`: `0x1785f53c` + `000000000000000000000000` + address
- `removeManager(address)`: `0xac18de43` + `000000000000000000000000` + address
- `removeOperator(address)`: `0xac8a584a` + `000000000000000000000000` + address
- `emergencyEtherWithdraw(address)`: `0x77964ad1` + `000000000000000000000000` + address

### Single Uint256 Parameter
- `setBaseFee(uint256)`: `0x46860698` + 32-byte padded uint256
- `setAdminThreshold(uint256)`: `0x5af28cf9` + 32-byte padded uint256
- `setManagerThreshold(uint256)`: `0x4fdfb1ad` + 32-byte padded uint256

### Three Parameters (address, address, uint256)
- `emergencyTokenWithdraw(address,address,uint256)`: `0xfef860b8` + 32-byte token address + 32-byte recipient address + 32-byte padded amount

---

**Contract Link**: https://sepolia.basescan.org/address/0x50b0a6391bb06cc0c7a228d41352ee91d496ae78#writeContract

