# Audit Findings: QubicToken.sol (Solidity / EVM)

**Source**: CertiK Preliminary Comments | Feb 18th, 2026
**Repository**: [vottundev/vottun-qubic-bridge-sc-evm](https://github.com/vottundev/vottun-qubic-bridge-sc-evm/tree/ca18ed4dc7cd00b31c347949ab50e3dec1191189/src)
**Commit**: `ca18ed4dc7cd00b31c347949ab50e3dec1191189`

---

## Summary

| Severity | Count | IDs |
|----------|:-----:|-----|
| Informational | 1 | QVB-28 |
| **Total** | **1** | |

`QubicToken.sol` received minimal findings in this audit. The single finding is shared with `QubicBridge.sol`.

---

## Informational

### QVB-28: Missing Interface Inheritance For Contract Implementation

| | |
|---|---|
| **Category** | Coding Issue |
| **Severity** | Informational |
| **Location** | `QubicBridge.sol` (Solidity): line 9 *(finding references both contracts)* |
| **Status** | Resolved |

**Description:**
Both `QubicBridge.sol` and `QubicToken.sol` implement their functionality directly without inheriting from or implementing explicit interface contracts. This leads to:

1. **Lack of Explicit Contract API**: Without interfaces, it's harder for external contracts to know which functions are available for interaction.
2. **Integration Difficulties**: Other contracts cannot easily reference the interface for type safety and compile-time checking.
3. **Upgradeability Challenges**: If the contract needs to be upgraded via proxy pattern, missing interfaces make it difficult to ensure backward compatibility.
4. **Documentation Gap**: Interfaces serve as formal documentation of the contract's public API.

**Recommendation:**
Create and inherit an `IQubicToken` interface file that defines the contract's public API, including:
- `mint(address to, uint256 amount)`
- `burn(address from, uint256 amount)`
- Role management functions
- Any other public/external functions

> Note: This finding is shared with `QubicBridge.sol` (see [audit-QubicBridge.md](audit-QubicBridge.md#qvb-28-missing-interface-inheritance-for-contract-implementation)).

**Solution Implemented:**
`QubicToken` now inherits from `IQubicToken`:
```solidity
contract QubicToken is IQubicToken, ERC20, AccessControlEnumerable {
```
The `IQubicToken.sol` interface defines:
- Custom error: `InvalidAmount()`
- Events: `Minted`, `Burned`, `AdminUpdated`, `OperatorAdded`, `OperatorRemoved`
- All public/external function signatures: `setAdmin`, `addOperator`, `removeOperator`, `mint`, `burn`, `getAdmin`, `getOperators`, `decimals`

Duplicate event and error declarations were removed from the contract (now inherited from the interface). The `decimals()` function override specifier was updated to `override(ERC20, IQubicToken)` to satisfy both parent contracts. Test files updated to reference `IQubicToken.EventName`.
