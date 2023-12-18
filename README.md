# ERC4337-Checker

This is a tool to help validate the ERC4337 limitations on forbidden opcodes and accessing disallowed storages. For detail specification, please read: [EIP4337 spec doc](https://eips.ethereum.org/EIPS/eip-4337#specification).

This is a library tool and intended to be use as a dependency and import to use in the forge tests.

To use this tool, you will need to use a specific forked version of forge.
1. Git clone from the [forked repo with tag v0.1.0-alpha-4337-tool](https://github.com/boolafish/foundry/releases/tag/v0.1.0-alpha-4337-tool).
2. Build the local from the fork:
```sh
# install Forge
cargo install --path ./crates/forge --profile local --force --locked
```


Also, you will need to replace the `forge-std` dependency to the following fork: [forked repo with tag v0.1.0-alpha-4337-tool](https://github.com/boolafish/forge-std/releases/tag/v0.1.0-alpha-4337-tool) in your target repository to use this library.

You can run the following commands to replace the `forge-std`:
```sh
forge remove foundry-rs/forge-std
forge install boolafish/forge-std@v0.1.0-alpha-4337-tool
```


After the forked `forge` and `forge-std` is setup, you can add this repository to your targe repo:
```sh
forge install boolafish/erc4337-checker
```

Now, you can start writing tests leveraging this ERC4337 checker! For a valid user operation, the following code should pass:

```solidity
import {ERC4337Checker} from "erc4337-checker/src/ERC4337Checker.sol";

...skip contract setups...

function testErc4337Restriction() public {
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
```
