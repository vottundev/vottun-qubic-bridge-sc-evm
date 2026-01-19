# Test Wallets Generator

## Overview

This tool generates test wallets with seed phrases for testing the QubicBridge multisig system on Base Sepolia testnet.

**⚠️ WARNING: These wallets are for TESTNET ONLY. Never use these private keys or seed phrases on mainnet!**

## Quick Start

### Prerequisites

- Node.js (v14 or higher)
- npm or yarn

### Installation

```bash
npm install
```

### Generate Wallets

```bash
npm run generate
```

Or directly:

```bash
node generate-test-wallets.js
```

## Output Files

The script generates three files:

1. **`test-wallets.json`** - Machine-readable JSON format
2. **`test-wallets.csv`** - CSV format for spreadsheet import
3. **`test-wallets.txt`** - Human-readable text format

## Wallet Roles

The script generates 6 wallets with the following roles:

1. **Admin 1** - For multisig admin operations
2. **Admin 2** - For multisig admin operations  
3. **Admin 3** - For multisig admin operations
4. **Manager 1** - For manager-level operations
5. **Manager 2** - For manager-level operations
6. **Operator 1** - For operator-level operations

## Using the Wallets

### 1. Fund Wallets with Test ETH

Fund each wallet with Base Sepolia ETH from a faucet:
- https://docs.base.org/docs/tools/network-faucets
- https://www.coinbase.com/faucets/base-ethereum-goerli-faucet

### 2. Import to MetaMask

**Option A: Import with Private Key**
1. Open MetaMask
2. Click account icon → Import Account
3. Paste the private key
4. Click Import

**Option B: Import with Seed Phrase**
1. Open MetaMask
2. Click account icon → Import Account
2. Select "Secret Recovery Phrase"
3. Paste the mnemonic phrase
4. Click Import

### 3. Configure Roles in Bridge Contract

After deployment, assign roles using the generated addresses:

**Admins** (3 wallets):
- Use as `_admins` array in constructor
- Set `adminThreshold` to 2 (2-of-3 multisig)

**Managers** (2 wallets):
- Add via `addManager()` proposal (admin function)
- Set `managerThreshold` to 2 (2-of-3 multisig)

**Operators** (1 wallet):
- Add via `addOperator()` proposal (manager function)

## Security Notes

1. **Never commit these files to git** - Add to `.gitignore`:
   ```
   test-wallets.json
   test-wallets.csv
   test-wallets.txt
   ```

2. **Testnet Only** - These wallets are generated for testing. Never use on mainnet.

3. **Share Securely** - If sharing with team, use encrypted channels or password-protected files.

4. **Regenerate** - You can run the script multiple times to generate new wallets.

## Example Output

```
================================================================================
WALLET 1: Admin 1
================================================================================
Address:     0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
Private Key: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
Mnemonic:    word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12
```

## Integration with Testing

### For Manual Testing (Explorer)

1. Import wallets to MetaMask
2. Switch to Base Sepolia network
3. Use addresses to test multisig proposals via Basescan

### For Automated Testing

Read the JSON file in your test scripts:

```javascript
const wallets = require('./test-wallets.json');
const admin1 = new ethers.Wallet(wallets.wallets[0].privateKey, provider);
```

## Troubleshooting

### "ethers not found"

Install dependencies:
```bash
npm install
```

### "Cannot find module"

Make sure you're in the project root directory and have run `npm install`.

### Need More Wallets

Edit `generate-test-wallets.js` and change `NUM_WALLETS` constant.

## Customization

To generate different numbers of wallets or different roles:

1. Edit `NUM_WALLETS` in `generate-test-wallets.js`
2. Update `WALLET_ROLES` array with desired role names
3. Run the script again

