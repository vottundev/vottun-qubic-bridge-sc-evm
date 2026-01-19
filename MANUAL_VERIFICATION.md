# Manual Verification Guide - QubicBridge

## Contract Information

- **Contract Address**: `0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc`
- **Network**: Base Sepolia (Chain ID: 84532)
- **Explorer**: https://sepolia.basescan.org/address/0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc

## Status

✅ Contract deployed successfully
✅ Bridge added as operator to token
⏳ Contract verification pending (API rate limit)

---

## Option 1: Automated Verification (After Rate Limit Reset)

Wait 1-2 hours and run:

```bash
bash verify_bridge.sh
```

Or manually:

```bash
forge verify-contract 0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc \
  src/QubicBridge.sol:QubicBridge \
  --chain base-sepolia \
  --etherscan-api-key R9QA73N9K75VQNPPE1W1VX14W8S83K2JJT \
  --constructor-args 0000000000000000000000005438615e84178c951c0eb84ec9af1045ea2a7c78000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000007002b4761b7b836b20f07e680b5b95c7551971020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000464800222d2ab38f696f0f74fe6a9fa5a2693e12000000000000000000000000db29aedd947eba1560dd31cffecf63bbb817ab4a0000000000000000000000007002b4761b7b836b20f07e680b5b95c755197102 \
  --watch
```

---

## Option 2: Manual Verification via BaseScan UI

### Step 1: Go to Contract Page

Visit: https://sepolia.basescan.org/address/0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc#code

### Step 2: Click "Verify and Publish"

### Step 3: Fill in the Form

#### Compiler Type
- Select: **Solidity (Single file)**

#### Compiler Version
- Select: **v0.8.30+commit.e4fa22e4**

#### Open Source License Type
- Select: **MIT License (MIT)**

#### Optimization
- Select: **Yes**
- Optimization Runs: **20000**

#### Enter the Solidity Contract Code
Use the flattened file: `QubicBridge_flat.sol`

Or compile manually:
```bash
forge flatten src/QubicBridge.sol > QubicBridge_flat.sol
```

#### Constructor Arguments ABI-encoded
```
0000000000000000000000005438615e84178c951c0eb84ec9af1045ea2a7c78000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000020000000000000000000000007002b4761b7b836b20f07e680b5b95c7551971020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000464800222d2ab38f696f0f74fe6a9fa5a2693e12000000000000000000000000db29aedd947eba1560dd31cffecf63bbb817ab4a0000000000000000000000007002b4761b7b836b20f07e680b5b95c755197102
```

**Decoded Constructor Arguments** (for reference):
```
address _token:            0x5438615E84178C951C0EB84Ec9Af1045eA2A7C78
uint256 _baseFee:          5
address[] _admins:         [
                             0x464800222D2AB38F696f0f74fe6A9fA5A2693E12,
                             0xDb29Aedd947eBa1560dd31CffEcf63bbB817aB4A,
                             0x7002b4761B7B836b20F07e680b5B95c755197102
                           ]
uint256 _adminThreshold:   2
uint256 _managerThreshold: 2
address _feeRecipient:     0x7002b4761B7B836b20F07e680b5B95c755197102
```

### Step 4: Complete CAPTCHA and Submit

### Step 5: Wait for Verification

Should take 1-2 minutes.

---

## Verification Checklist

- [ ] Wait 1-2 hours for API rate limit reset
- [ ] Run automated verification script OR
- [ ] Manually verify via BaseScan UI
- [ ] Confirm contract is verified at https://sepolia.basescan.org/address/0xbC79b4a96186b0AFE09Ee83830e2Fb30E14d5Ddc#code

---

## Deployment Details

```
Deployed: 2025-01-XX
Deployer: 0x0e60B83F83c5d2684acE779dea8A957e91D02475
Gas Used: 6,530,163
Network:  Base Sepolia (84532)

Configuration:
- Token:            0x5438615E84178C951C0EB84Ec9Af1045eA2A7C78
- Base Fee:         5 (0.05%)
- Admin Threshold:  2 (2-of-3)
- Manager Threshold: 2 (2-of-3)
- Fee Recipient:    0x7002b4761B7B836b20F07e680b5B95c755197102

Admins:
- Admin 1: 0x464800222D2AB38F696f0f74fe6A9fA5A2693E12
- Admin 2: 0xDb29Aedd947eBa1560dd31CffEcf63bbB817aB4A
- Admin 3: 0x7002b4761B7B836b20F07e680b5B95c755197102

Features:
✅ Multisig 2-of-3 for admin functions
✅ Multisig 2-of-3 for manager functions
✅ Threshold protection (prevents contract lockout)
✅ Bridge is operator of token
```
