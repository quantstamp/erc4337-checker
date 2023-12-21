# ERC4337-Checker

This is a tool to help validate the ERC4337 limitations on forbidden opcodes and accessing disallowed storages. For detail specification, please read: [EIP4337 spec doc](https://eips.ethereum.org/EIPS/eip-4337#specification).

This is a library tool and intended to be use as a dependency and import to use in the forge tests.
The tool is only compatible with the reference implementation of account abstraction: https://github.com/eth-infinitism/account-abstraction/. Currently, this tool is tested with the `v0.6.0` version of the `account-abstraction` repo.

To use this tool, you will need to use a specific forked version of forge.
1. Git clone from the [forked repo with tag v0.1.0-alpha-4337-tool](https://github.com/quantstamp/foundry/releases/tag/v0.1.0-alpha-4337-tool).
2. Build the local from the fork:
```sh
# install Forge
cargo install --path ./crates/forge --profile local --force --locked
```


Also, you will need to replace the `forge-std` dependency to the following fork: [forked repo with tag v0.1.0-alpha-4337-tool](https://github.com/quantstamp/forge-std/releases/tag/v0.1.0-alpha-4337-tool) in your target repository to use this library.

You can run the following commands to replace the `forge-std`:
```sh
forge remove foundry-rs/forge-std
forge install quantstamp/forge-std@v0.1.0-alpha-4337-tool
```


After the forked `forge` and `forge-std` is setup, you can add this repository to your targe repo:
```sh
forge install quantstamp/erc4337-checker
```

Now, you can start writing tests leveraging this ERC4337 checker! The tool support validate on both userOp or bundle level.

```solidity
import {Vm} from "forge-std/Vm.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

import {ERC4337Checker} from "erc4337-checker/src/ERC4337Checker.sol";


Contract YourTest {
    function setUp() public {
        entryPoint = new EntryPoint();
        mockAccount = new MockAccount(entryPoint);
        vm.deal(address(mockAccount), 1 << 128); // give some funds to the mockAccount
    }

    function testSingleUserOp() public {
        UserOperation memory userOp = getUserOperationAndSign(...) // <-- put your own logic here

        ...skip some codes...

        // this starts the recording of the debug trace that will later be analyzed
        vm.startDebugTraceRecording();

        try entryPoint.simulateValidation(userOp) {
            // the simulateValidation function will always revert.
            // in this test, we do not really care if it is revert in an expected output or not.
        } catch (bytes memory reason) {
            // if not fail with ValidationResult error, it is likely to be something unexpected.
            if (reason.length < 4 || bytes4(reason) != IEntryPoint.ValidationResult.selector) {
                revert(string(abi.encodePacked(
                    "simulateValidation call failed unexpectedly: ", reason
                )));
            }
        }

        // collect the recorded opcodes, stack and memory inputs.
        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        // verify that the user operation fulfills the spec's limitation
        assertTrue(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }


    function testBundle() public {
        UserOperation[] memory userOps = getUserOperationsAndSign(...) // <-- put your own logic here

        ...skip some codes...

        // this starts the recording of the debug trace that will later be analyzed
        vm.startDebugTraceRecording();

        // simulate all userOps
        for (uint i = 0 ; i < userOps.length ; i++) {
            UserOperation userOp = userOps[i]
            try entryPoint.simulateValidation(userOp) {
                // the simulateValidation function will always revert.
                // in this test, we do not really care if it is revert in an expected output or not.
            } catch (bytes memory reason) {
                // if not fail with ValidationResult error, it is likely to be something unexpected.
                if (reason.length < 4 || bytes4(reason) != IEntryPoint.ValidationResult.selector) {
                    revert(string(abi.encodePacked(
                        "simulateValidation call failed unexpectedly: ", reason
                    )));
                }
            }
        }

        // collect the recorded opcodes, stack and memory inputs.
        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        // Similar to validateUserOp(), but also checks that there is no duplicate
        // storage slot access across userOps.
        assertTrue(
            ERC4337Checker.validateBundle(steps, userOp, entryPoint)
        );
    }
}
```

If the existing tests have self-defined interfaces or structs, one can use `import {A as B} from '....'` to avoid name collision.

```solidity
// use AA prefix to avoid collision with the self-defined interfaces/structs later
import {IEntryPoint as AAIEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation as AAUserOperation} from "account-abstraction/interfaces/UserOperation.sol";

...skip...
// collision interfaces/struct
import {IEntryPoint} from "../../src/interfaces/erc4337/IEntryPoint.sol";
import {UserOperation} from "../../src/interfaces/erc4337/UserOperation.sol";

import {ERC4337Checker} from "erc4337-checker/src/ERC4337Checker.sol";
import {Vm} from "forge-std/Vm.sol";

contract YourTest {
    function test_simulateValidation_basicUserOp() public {
        ...skip code...
        // Self defined UserOperation struct
        UserOperation memory userOp = UserOperation(....);

        ...skip code...

        // Adapt to the AAUserOperation using the struct from the `eth-infinitism/account-abstraction`
        AAUserOperation memory aaUserOp = AAUserOperation({
            sender: userOp.sender,
            nonce: userOp.nonce,
            initCode: userOp.initCode,
            callData: userOp.callData,
            callGasLimit: userOp.callGasLimit,
            verificationGasLimit: userOp.verificationGasLimit,
            preVerificationGas: userOp.preVerificationGas,
            maxFeePerGas: userOp.maxFeePerGas,
            maxPriorityFeePerGas: userOp.maxPriorityFeePerGas,
            paymasterAndData: userOp.paymasterAndData,
            signature: userOp.signature
        });

        vm.startDebugTraceRecording();

        // cast IEntryPoint -> EntryPoint
        try EntryPoint(payable(address(entryPoint))).simulateValidation(aaUserOp) {
            // the simulateValidation function will always revert.
            // in this test, we do not really care if it is revert in an expected output or not.
        } catch (bytes memory reason) {
            // if not fail with ValidationResult error, it is likely to be something unexpected.
            //
            // Using AAIEntryPoint here to avoid collision.
            if (reason.length < 4 || bytes4(reason) != AAIEntryPoint.ValidationResult.selector) {
                revert(string(abi.encodePacked("simulateValidation call failed unexpectedly: ", reason)));
            }
        }

        // collect the recorded opcodes, stack and memory inputs.
        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        // verify that the user operation fulfills the spec's limitation
        assertTrue(
            ERC4337Checker.validateUserOp(steps, aaUserOp, EntryPoint(payable(address(entryPoint))))
        );
    }
}

```
