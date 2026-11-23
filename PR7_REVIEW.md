# PR #7 Review: Make code compatible with v0.8 ERC-4337 reference implementation

**Reviewer:** Claude (Security Audit)  
**PR:** https://github.com/quantstamp/erc4337-checker/pull/7  
**Branch:** `feat/v0.8-compatible` -> `main`  
**Date:** 2026-01-29  

---

## Overview

This PR migrates the `erc4337-checker` Foundry test library from the eth-infinitism account-abstraction **v0.6** reference implementation to **v0.8**. The changes span 6 files: 2 submodule pointer updates, the main library contract, the test file, and both mock contracts.

### Relevant ERC Standards

- **ERC-4337**: Account Abstraction Using Alt Mempool — defines the `PackedUserOperation` struct, `EntryPoint` interface, and the overall Account Abstraction protocol.
- **ERC-7562**: Account Abstraction Validation Scope Rules — defines the validation rules (forbidden opcodes, storage rules, code rules, etc.) that this checker library aims to enforce.

---

## Background: What Changed Between v0.6 and v0.8

| Feature | v0.6 | v0.8 |
|---|---|---|
| UserOp struct | `UserOperation` (11 separate fields) | `PackedUserOperation` (9 fields, gas limits/fees packed into `bytes32`) |
| Simulation | `EntryPoint.simulateValidation()` — always **reverts** with `IEntryPoint.ValidationResult` error | `EntryPointSimulations.simulateValidation()` — **returns** `IEntryPointSimulations.ValidationResult` struct |
| BaseAccount | No `execute()` function | Has `execute()` and `executeBatch()` functions |
| BasePaymaster | Simple constructor, no interface check | Constructor calls `_validateEntryPointInterface()` requiring `supportsInterface` |
| OpenZeppelin | v4.9.3 | v5.5.0 (needed for `ReentrancyGuardTransient`) |

---

## Findings

### 1. CRITICAL — Removal of CREATE Opcode Validation Weakens ERC-7562 Compliance

**Files:** `src/ERC4337Checker.sol` (validateForbiddenOpcodes), `test/mocks/MockAccount.sol`, `test/ERC4337Checker.t.sol`

The PR completely removes the `CREATE` (`0xF0`) opcode exception handling logic from `validateForbiddenOpcodes()` and removes the corresponding `FORBIDDEN_OPCODE_CREATE` attack type from the mock account and its test case (`test_forbiddenOpCodeCreate`).

Per **ERC-7562 [OP-011]**, `CREATE` (`0xF0`) is a **blocked opcode** — with specific exceptions:

- **[OP-032]**: If there is a factory (even unstaked), the **sender contract itself** is allowed to use `CREATE`. Not utility contracts — only the sender.
- **[EREP-061]**: A **staked factory** may also use a utility contract that calls `CREATE`.

The original code correctly enforced [OP-032]: it allowed `CREATE` only when a factory existed AND only when executed directly by `userOp.sender`. The PR removes this logic entirely.

After removal, the `CREATE` opcode (`0xF0`) **is still listed in `isForbiddenOpcode()`** but the special-case exception handling was deleted. The consequence:

- `CREATE` is now **always** flagged as a generic "forbidden op-code", even in the legitimate case where the sender uses it with a factory present.
- This means the checker **over-reports** — legitimate use of `CREATE` by the sender (per [OP-032]) is incorrectly flagged as a violation.
- The test covering this case (`test_forbiddenOpCodeCreate`) was removed, so this regression is invisible.

**Recommendation:** Restore the `CREATE` exception logic. The `userOp` parameter must be re-added to `validateForbiddenOpcodes()` to enable the factory address and sender address checks required by [OP-032]. Also restore the test case.

---

### 2. HIGH — Silent Swallowing of All Simulation Errors

**File:** `src/ERC4337Checker.sol` — `simulateAndVerifyUserOp()` and `simulateAndVerifyBundle()`

In v0.6, `simulateValidation()` always reverted — on success it reverted with `IEntryPoint.ValidationResult`, and on failure with some other error. The original code correctly distinguished these:

```solidity
// BEFORE (v0.6)
} catch (bytes memory reason) {
    if (reason.length < 4 || bytes4(reason) != IEntryPoint.ValidationResult.selector) {
        revert(string(abi.encodePacked(
            "simulateValidation call failed unexpectedly: ", reason
        )));
    }
}
```

In v0.8, `EntryPointSimulations.simulateValidation()` **returns** the `ValidationResult` instead of reverting with it. It can still revert on actual errors (e.g., `FailedOp("AA20 account not deployed")`, `FailedOp("AA25 invalid account nonce")`, etc.).

The PR changes the catch block to:

```solidity
// AFTER (v0.8 PR)
} catch {
    
}
```

This silently swallows **all** reverts, including legitimate failures like:

- `FailedOp(0, "AA20 account not deployed")`
- `FailedOp(0, "AA25 invalid account nonce")`
- `FailedOp(0, "AA30 paymaster not deployed")`
- Any other unexpected revert

The checker will then proceed to analyze whatever debug trace was captured up to the revert point, potentially producing misleading results or even passing validation on a UserOperation that the EntryPoint itself rejected.

**Recommendation:** The `try` block should capture the return value for the success case. The `catch` block should propagate unexpected errors:

```solidity
try entryPoint.simulateValidation(userOp) returns (IEntryPointSimulations.ValidationResult memory) {
    // success — simulation completed, proceed to trace analysis
} catch (bytes memory reason) {
    // simulateValidation reverted — this is a genuine failure in v0.8
    revert(string(abi.encodePacked(
        "simulateValidation call failed: ", reason
    )));
}
```

---

### 3. MEDIUM — `validateForbiddenOpcodes` Lost `userOp` Parameter

**File:** `src/ERC4337Checker.sol`

The function signature changed from:

```solidity
function validateForbiddenOpcodes(Vm.DebugStep[] memory debugSteps, UserOperation memory userOp) private returns (bool)
```

to:

```solidity
function validateForbiddenOpcodes(Vm.DebugStep[] memory debugSteps) private returns (bool)
```

The `userOp` parameter was removed because the CREATE exception logic (which needed it for `getFactoryAddr(userOp)` and `userOp.sender`) was deleted.

This makes it impossible to re-add the [OP-032] CREATE exception without re-introducing the parameter. Since the CREATE handling must be restored (see Finding #1), the parameter must come back.

**Recommendation:** Restore `PackedUserOperation memory userOp` as a parameter to `validateForbiddenOpcodes()`.

---

### 4. MEDIUM — `isFromAccount` Parameter Fix Is Correct (Positive Finding)

**File:** `src/ERC4337Checker.sol` — `validateUserOp()` and `validateSteps()`

The PR adds a `bool isFromAccount` parameter to `validateSteps()` and correctly passes `true` for sender validation and `false` for paymaster validation:

```solidity
if (!validateSteps(senderSteps, userOp, entryPoint, true)) { ... }
if (!validateSteps(paymasterSteps, userOp, entryPoint, false)) { ... }
```

Previously this was hardcoded as `true` for both calls, which was a pre-existing bug. The fix is correct: per **ERC-7562 [OP-061]**, `CALL` with value is forbidden except from the account to the EntryPoint. Passing `false` for paymaster validation means the paymaster correctly cannot send value at all (even to the EntryPoint). This aligns with the spec.

**No action needed — this is a correctness improvement.**

---

### 5. MEDIUM — Error Message References Wrong Contract Name

**File:** `src/ERC4337Checker.sol` line ~376 (after diff)

```solidity
errorMsg: "cannot call EntryPointSimulations methods, except depositTo",
```

The error message was changed from "EntryPoint" to "EntryPointSimulations". While technically the code now uses `EntryPointSimulations`, from the ERC-4337 protocol perspective this contract serves as the EntryPoint for simulation purposes. Users of the library will see "EntryPointSimulations" in error messages when the spec violation is about calling EntryPoint methods. This is cosmetically confusing.

**Recommendation:** Keep the message as `"cannot call EntryPoint methods, except depositTo"` since the rule is about the EntryPoint interface per ERC-7562 [OP-054], not the specific simulation contract.

---

### 6. LOW — `_validateEntryPointInterface` Override Comment Is Insufficient

**File:** `test/mocks/MockPaymaster.sol`

The PR adds:

```solidity
function _validateEntryPointInterface(IEntryPoint _entryPoint) internal override {
    // Skip validation for testing
}
```

This is needed because `EntryPointSimulations.supportsInterface()` returns `false` for all interfaces:

```solidity
// In EntryPointSimulations.sol:
function supportsInterface(bytes4) public view virtual override returns (bool) {
    return false;
}
```

So the `BasePaymaster` constructor's `_validateEntryPointInterface` call would revert. The override is necessary for testing but the comment doesn't explain why.

**Recommendation:** Expand the comment to:
```solidity
// EntryPointSimulations.supportsInterface() returns false for all interfaces; skip for testing
```

---

### 7. LOW — Test Gas Values Exceed ERC-7562 Spec Constants

**File:** `test/ERC4337Checker.t.sol` — `_getUnsignedOp()`

```solidity
accountGasLimits: bytes32((uint256(5_000_000) << 128) | uint256(30_000_000)),
gasFees: bytes32((uint256(5_000_000) << 128) | uint256(30_000_000)),
```

The `accountGasLimits` packs:
- `verificationGasLimit` (high 128 bits) = 5,000,000
- `callGasLimit` (low 128 bits) = 30,000,000

Per **ERC-7562 constant `MAX_VERIFICATION_GAS`** = 500,000, the verification gas limit of 5,000,000 exceeds the spec limit by 10x. While this is test code, using spec-compliant values would better exercise realistic conditions.

**Recommendation:** Consider using values within spec bounds, e.g.:

```solidity
accountGasLimits: bytes32((uint256(500_000) << 128) | uint256(1_000_000)),
gasFees: bytes32((uint256(1 << 8) << 128) | uint256(1 << 8)),
```

---

### 8. LOW — MockAccount Deposit Added in setUp (Correct Fix)

**File:** `test/ERC4337Checker.t.sol` — `setUp()`

The PR adds:

```solidity
entryPoint.depositTo{value: 1 ether}(address(mockAccount));
```

In v0.8, the account needs a deposit in the EntryPoint to cover gas costs during simulation. This is a correct and necessary fix for the migration.

---

### 9. LOW — Missing Newline at End of Test File

**File:** `test/ERC4337Checker.t.sol`

The diff shows the file no longer ends with a newline (`\ No newline at end of file`). `forge fmt` should fix this.

---

### 10. INFORMATIONAL — Pre-existing ERC-7562 Compliance Gaps (Not Introduced by This PR)

These are not regressions but are worth noting for completeness since this checker aims to enforce ERC-7562:

| Rule | Gap |
|---|---|
| **[OP-080]** | `BALANCE` (`0x31`) and `SELFBALANCE` (`0x47`) are listed as forbidden in `isForbiddenOpcode()`, but the spec says they are "allowed only from a staked entity." The checker flags them unconditionally without checking stake status. |
| **[OP-013]** | "Unassigned" opcodes are not checked. |
| **[OP-070]** | `TLOAD` (`0x5C`) and `TSTORE` (`0x5D`) should be treated like `SLOAD`/`SSTORE` for storage validation. The checker only checks `0x54`/`0x55`. |
| **[STO-021]/[STO-022]** | The checker doesn't distinguish between existing accounts and accounts being deployed via initCode when validating associated storage access. |
| **[OP-051]-[OP-055]** | EntryPoint call validation is incomplete. Only `depositTo` is allowed; `incrementNonce()` from the sender [OP-055] and the fallback function from the sender [OP-053] are not specifically handled. |
| **Factory frame** | The checker only extracts sender and paymaster debug steps. It does not extract or validate the factory/deployment frame, which has its own set of rules (e.g., [OP-031] allowing exactly one `CREATE2`). |

---

## Summary Table

| # | Severity | Finding | Action Required |
|---|---|---|---|
| 1 | **Critical** | Removal of CREATE opcode exception logic breaks [OP-032] compliance | Restore CREATE exception handling and test |
| 2 | **High** | Silent swallowing of all simulation errors via bare `catch {}` | Add proper error propagation for v0.8 return model |
| 3 | **Medium** | `validateForbiddenOpcodes` lost `userOp` parameter | Restore parameter for [OP-032] support |
| 4 | **Medium** | `isFromAccount` parameter fix (positive) | None — correct improvement |
| 5 | **Medium** | Error message incorrectly says "EntryPointSimulations" | Revert to "EntryPoint" |
| 6 | **Low** | `_validateEntryPointInterface` override comment insufficient | Expand comment |
| 7 | **Low** | Test gas values exceed ERC-7562 `MAX_VERIFICATION_GAS` | Consider spec-compliant values |
| 8 | **Low** | MockAccount deposit added in setUp (positive) | None — correct fix |
| 9 | **Low** | Missing EOF newline in test file | Run `forge fmt` |
| 10 | **Info** | Pre-existing ERC-7562 gaps ([OP-080], [OP-070], [OP-013], [OP-055], factory frame) | Future work |

---

## Verdict

The mechanical type migration (`UserOperation` -> `PackedUserOperation`, `EntryPoint` -> `EntryPointSimulations`) is correct and necessary. The `isFromAccount` fix (Finding #4) is a genuine improvement.

However, the PR introduces two significant regressions:

1. **The CREATE validation logic removal (Finding #1)** breaks the checker's ability to correctly assess [OP-032] compliance. Legitimate uses of `CREATE` by the sender with a factory are now false-positived, and the test was removed to hide the regression.

2. **The silent error swallowing (Finding #2)** means malformed UserOperations that fail basic EntryPoint checks will be silently accepted into trace analysis rather than being flagged as invalid.

**Recommendation:** Address findings #1 and #2 before merging. The remaining findings are lower severity and can be addressed in follow-up work.
