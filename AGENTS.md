# Agent Guide (erc4337-checker)

This repo is a Foundry (Forge) Solidity project that provides an ERC-4337 validation helper (`ERC4337Checker`) intended to be imported into other Foundry test suites.

## Quick Orientation

- `src/`: library contracts (main: `src/ERC4337Checker.sol`)
- `test/`: Foundry tests (main: `test/ERC4337Checker.t.sol` + `test/mocks/*`)
- `script/`: Foundry scripts (example: `script/Counter.s.sol`)
- `lib/`: git submodules
  - `lib/account-abstraction` (eth-infinitism AA reference implementation)
  - `lib/forge-std` (Foundry test utilities)
  - `lib/openzeppelin-contracts`
- Tooling config: `foundry.toml`, `remappings.txt`

## Environment Setup

1. Install Foundry: https://getfoundry.sh
2. Use a nightly Foundry version that includes `vm.startDebugTraceRecording()` / `vm.stopAndReturnDebugTraceRecording()`:
   - `foundryup` (nightly is used in CI)
3. Ensure submodules are present:
   - `git submodule update --init --recursive`

Notes:
- This project is only known to be compatible with `eth-infinitism/account-abstraction` (see README).
- CI sets `FOUNDRY_PROFILE=ci` (see `.github/workflows/test.yml`).

## Build / Format / Test Commands

### Build

- Build (local):
  - `forge build`
- Build with contract size output (matches CI):
  - `forge build --sizes`
- Clean build artifacts:
  - `forge clean`

### Format (acts as “lint”)

This repo does not currently configure ESLint/solhint; rely on Foundry formatting.

- Auto-format Solidity:
  - `forge fmt`
- Check formatting (CI-friendly):
  - `forge fmt --check`

### Tests

Important: tests that rely on debug tracing should be run with high verbosity so the tracer is enabled.

- Run full test suite (recommended):
  - `forge test -vvv`
- Run tests with CI profile (matches GitHub Actions):
  - `FOUNDRY_PROFILE=ci forge test -vvv`

### Run a Single Test

Use `--match-test` / `--match-contract` / `--match-path`.

- Single test by function name:
  - `forge test -vvv --match-test test_validationPass`
- Single test by regex:
  - `forge test -vvv --match-test "test_forbiddenOpCode.*"`
- Single test contract:
  - `forge test -vvv --match-contract ERC4337CheckerTest`
- Single test file:
  - `forge test -vvv --match-path test/ERC4337Checker.t.sol`

### Useful Debug Flags

- Print traces (noisy):
  - `forge test -vvvv`
- Run only failing tests:
  - `forge test -vvv --rerun`

## Coding Guidelines (Solidity)

### Formatting

- Use `forge fmt` before finalizing changes.
- Keep lines reasonably short; let `forge fmt` handle wrapping.
- Prefer multi-line argument lists when readability improves (existing code uses this style).

### Imports

Preferred import style is explicit named imports:

- `import {Test, console2} from "forge-std/Test.sol";`
- `import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";`

Guidelines:
- Group imports by origin with a blank line between groups:
  1) `forge-std/*`
  2) `account-abstraction/*`
  3) `openzeppelin-contracts/*`
  4) local imports (`../src/...`, `./mocks/...`)
- Avoid wildcard imports.
- If names collide, alias imports (see README example):
  - `import {UserOperation as AAUserOperation} from "...";`

### Pragma / SPDX

- Keep the SPDX identifier at the top of each file.
- Match the existing pragma conventions in the touched file (do not mass-upgrade pragmas).
- This repo’s `foundry.toml` uses `solc = "0.8.30"`; code should remain compatible.

### Naming Conventions

- Contracts: `PascalCase` (e.g., `ERC4337Checker`, `MockAccount`).
- Structs / Enums: `PascalCase` (e.g., `FailureLog`, `AttackType`).
- Functions: `lowerCamelCase`.
- Internal/private helper functions: prefix with `_` (e.g., `_decodeAttackType`).
- Variables:
  - public state: `lowerCamelCase`
  - private state: `lowerCamelCase` with `_` prefix (e.g., `_entryPoint`)
- Tests:
  - follow Foundry conventions: `setUp()` and `test_*` functions

### Types and Data Locations

- Be explicit with data locations: `memory`, `calldata`, `storage`.
- Use `uint256` for arithmetic and loop counters unless a smaller type is clearly correct.
- When dealing with EVM words (stack/memory), be explicit about conversions (`bytes32`, `uint256`).

### Error Handling

- Prefer `require(condition, "message")` for argument validation and invariants.
- Use `revert(...)` when bubbling up rich context is helpful.
- When using `try/catch` around `EntryPoint.simulateValidation`, keep the existing invariant:
  - `simulateValidation` is expected to revert with `IEntryPoint.ValidationResult`.
  - Any other revert should be treated as unexpected.

### Logging / Debugging

- `console2` is used for debug output.
- Don’t leave excessive logging in library code unless it materially helps users.
- For tests that expect failures, call `checker.printFailureLogs()` after assertions to show why.

### Gas / Complexity

- Avoid quadratic loops over large dynamic arrays in production-facing code; keep validation logic bounded where possible.
- Prefer early `continue`/`return` for readability in opcode scans.

## Foundry / Project Conventions

- Remappings:
  - `@openzeppelin/` is mapped via `remappings.txt`.
  - `openzeppelin-contracts` is imported directly in code; keep consistent.
- CI:
  - Runs `forge build --sizes` then `forge test -vvv` with `FOUNDRY_PROFILE=ci`.

## Cursor/Copilot Rules

- No `.cursorrules`, `.cursor/rules/*`, or `.github/copilot-instructions.md` were found in this repository at the time this file was generated.
