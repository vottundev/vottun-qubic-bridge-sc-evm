# VottunBridge Solidity Contracts - Security Issues Tracker

## Working Document - Issues to Fix

This document tracks the security findings specific to the Solidity/EVM contracts in the VottunBridge project. We'll update the status as we fix each issue.

**Project Scope:** Solidity contracts for Ethereum/EVM side of the bridge  
**Contracts:** QubicBridge.sol, QubicToken.sol  
**Status:** Work in Progress  

---

## 📊 Issues Summary

| ID | Severity | Status | Contract | Title |
|----|----------|--------|----------|-------|
| KS–VB–F–05 | Low | ✅ Fixed | Multiple | Floating Pragmas |
| KS–VB–F–06 | Low | ✅ Fixed | QubicBridge.sol | Lack of Input Sanitization |
| KS–VB–F–07 | Low | 🔴 Open | QubicBridge.sol | Missing Checksum Validation |
| KS–VB–O–03 | Informational | 🔴 Open | Dependencies | Dependency Added using Unstable Branch |
| KS–VB–O–05 | Informational | 🔴 Open | QubicToken.sol | Zero Address Verification Not Performed |
| KS–VB–O–06 | Informational | 🔴 Open | Multiple | Ethereum Addresses Storage Inconsistencies |
| KS–VB–O–07 | Informational | 🔴 Open | Multiple | Amount Verification Inconsistencies |

**Legend:** 🔴 Open | 🟡 In Progress | ✅ Fixed | ❌ Not Applicable

**Progress:** 2/7 issues fixed (28.6%)

---

## 🔴 Low Severity Issues

### KS–VB–F–05 Floating Pragmas

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Low | Medium | ✅ **FIXED** |

#### Description
The contracts use floating pragma statements (e.g., `pragma solidity ^0.8.0;`) instead of locking to a specific compiler version. This can lead to unexpected behavior if compiled with different compiler versions.

#### Impact
- **Deployment Inconsistencies**: Different compiler versions may produce different bytecode
- **Unexpected Behavior**: New compiler versions may introduce breaking changes
- **Security Risk**: Newer compilers may have different optimization behaviors

#### Affected Files
- All Solidity contracts with floating pragmas

#### Recommendation
Lock pragma to specific compiler version:
```solidity
// Instead of:
pragma solidity ^0.8.0;

// Use:
pragma solidity 0.8.19;
```

#### Fix Status
- [x] Identify all contracts with floating pragmas
- [x] Choose target Solidity version (0.8.19)
- [x] Update all pragma statements
- [x] Test compilation and deployment
- [x] Update documentation

---

### KS–VB–F–06 Lack of Input Sanitization

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Medium | Medium | 🔴 **OPEN** |

#### Description
The `confirmOrder` and `revertOrder` functions in QubicBridge.sol do not validate that the `feePct` parameter does not exceed 100%, unlike the `executeOrder` function which has this check.

#### Impact
- **Fee Calculation Errors**: Fees could exceed 100% of the transaction amount
- **Economic Exploit**: Malicious actors could set excessive fees
- **User Loss**: Users could lose more than intended in fees

#### Evidence
```solidity
// Missing in confirmOrder and revertOrder:
if (feePct > 100) {
    revert InvalidFeePercentage();
}
```

#### Affected Files
- QubicBridge.sol: `confirmOrder` function
- QubicBridge.sol: `revertOrder` function

#### Recommendation
Add input validation for `feePct` parameter:
```solidity
if (feePct > 100) {
    revert InvalidFeePercentage();
}
```

#### Fix Status
- [ ] Add validation to `confirmOrder` function
- [ ] Add validation to `revertOrder` function
- [ ] Add custom error `InvalidFeePercentage`
- [ ] Write unit tests for validation
- [ ] Update function documentation

---

### KS–VB–F–07 Missing Checksum Validation

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Low | Low | Low | 🔴 **OPEN** |

#### Description
The `isQubicAddress` function in QubicBridge.sol checks character validity but does not verify the checksum portion of Qubic addresses, which could lead to accepting invalid addresses.

#### Impact
- **Invalid Transactions**: Transactions to invalid Qubic addresses
- **Fund Loss**: Potential loss of funds sent to invalid addresses
- **User Experience**: Poor UX with failed transactions

#### Evidence
```solidity
function isQubicAddress(string memory addr) internal pure returns (bool) {
    // Only checks character validity, not checksum
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
    return true; // Missing checksum validation
}
```

#### Affected Files
- QubicBridge.sol lines 424-449

#### Recommendation
Implement proper checksum validation based on Qubic address specification.

#### Reference
- [Qubic CLI Key Utils](https://github.com/qubic/qubic-cli/blob/main/keyUtils.cpp)

#### Fix Status
- [ ] Research Qubic checksum algorithm
- [ ] Implement checksum validation function
- [ ] Update `isQubicAddress` function
- [ ] Write comprehensive tests
- [ ] Validate against known good/bad addresses

---

## 🔵 Informational Issues

### KS–VB–O–03 Dependency Added using Unstable Branch

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Informational | Low | Low | 🔴 **OPEN** |

#### Description
The project uses OpenZeppelin dependencies from the master branch instead of stable tagged releases, which can introduce instability and security risks.

#### Impact
- **Unstable Dependencies**: Master branch may contain breaking changes
- **Security Risk**: Unvetted code in development branches
- **Build Inconsistency**: Different builds may use different dependency versions

#### Affected Files
- `.gitmodules` file
- Package dependency configuration

#### Recommendation
Use stable tagged releases instead of master branch:
```
# Instead of master branch, use tagged release
https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v4.9.3
```

#### Fix Status
- [ ] Identify current OpenZeppelin version being used
- [ ] Choose appropriate stable release
- [ ] Update dependency configuration
- [ ] Test with new dependency version
- [ ] Update documentation

---

### KS–VB–O–05 Zero Address Verification Not Performed

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Informational | Medium | Low | 🔴 **OPEN** |

#### Description
The `setAdmin` and `addOperator` functions in QubicToken.sol do not validate that the provided addresses are not the zero address, which could lead to loss of control.

#### Impact
- **Loss of Control**: Setting admin to zero address makes contract unmanageable
- **Operational Risk**: Cannot recover from zero address assignment
- **Security Risk**: Contract becomes permanently locked

#### Affected Files
- QubicToken.sol: `setAdmin` function (lines 24-43)
- QubicToken.sol: `addOperator` function

#### Recommendation
Add zero address validation:
```solidity
require(newAdmin != address(0), "Admin cannot be zero address");
require(newOperator != address(0), "Operator cannot be zero address");
```

#### Fix Status
- [ ] Add zero address check to `setAdmin`
- [ ] Add zero address check to `addOperator`
- [ ] Add appropriate error messages
- [ ] Write unit tests for validation
- [ ] Update function documentation

---

### KS–VB–O–06 Ethereum Addresses Storage Inconsistencies

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Informational | Low | Low | 🔴 **OPEN** |

#### Description
Inconsistencies in how Ethereum addresses are stored and handled across different contracts.

#### Impact
- **Data Inconsistency**: Different address formats in different contexts
- **Integration Issues**: Potential problems when contracts interact
- **Maintenance Overhead**: Harder to maintain consistent address handling

#### Fix Status
- [ ] Audit all address storage patterns
- [ ] Identify inconsistencies
- [ ] Standardize address handling
- [ ] Update affected contracts
- [ ] Document address handling standards

---

### KS–VB–O–07 Amount Verification Inconsistencies

| Severity | Impact | Likelihood | Status |
|----------|--------|------------|--------|
| Informational | Low | Low | 🔴 **OPEN** |

#### Description
Inconsistent patterns for amount validation across different functions and contracts.

#### Impact
- **Logic Inconsistency**: Different validation rules in similar contexts
- **Potential Bugs**: Inconsistent validation may lead to edge case bugs
- **Code Quality**: Reduces code maintainability and readability

#### Fix Status
- [ ] Audit all amount validation patterns
- [ ] Identify inconsistencies
- [ ] Standardize validation logic
- [ ] Create reusable validation functions
- [ ] Update affected contracts

---

## 🎯 Next Steps

### Priority 1 (Security Critical)
1. **KS–VB–F–06**: Input sanitization for fee percentages
2. **KS–VB–F–07**: Qubic address checksum validation

### Priority 2 (Best Practices)
3. **KS–VB–F–05**: Lock pragma versions
4. **KS–VB–O–05**: Zero address validation

### Priority 3 (Code Quality)
5. **KS–VB–O–03**: Stable dependency versions
6. **KS–VB–O–06**: Address storage consistency
7. **KS–VB–O–07**: Amount validation consistency

---

## 📝 Notes

- This is a working document - update status as issues are resolved
- Each fix should include proper testing
- Document any design decisions or trade-offs
- Final report will be generated once all issues are addressed

**Last Updated:** January 2025  
**Status:** Ready to begin fixes
