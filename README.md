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

        checker = new ERC4337Checker(); // initiate the checker contract
    }

    function testSingleUserOp() public {
        UserOperation memory userOp = getUserOperationAndSign(...) // <-- put your own logic here

        ...skip some codes...

        // a single line that will do all the magic!
        // this function calls `simulateValidation()` and capture the
        // debugging steps and do the validations!
        bool result = checker.simulateAndVerifyUserOp(vm, userOp, entryPoint);

        // To debug, this will output all failure logs telling what rules are violated.
        // To see the logs, please run the test with `forge test -vvv`
        // you would not need this usually, only needed when the test failed unexpectedly.
        checker.printFailureLogs();

        assertTrue(result);
    }


    function testBundle() public {
        UserOperation[] memory userOps = getUserOperationsAndSign(...) // <-- put your own logic here

        ...skip some codes...

        // this starts the recording of the debug trace that will later be analyzed
        vm.startDebugTraceRecording();

        // just put all your userOps of the bundle in, and this will run the simulation for all the user ops
        // and check bundle specific rules
        assertTrue(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
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


        assertTrue(checker.simulateAndVerifyUserOp(vm, aaUserOp, entryPoint));
    }
}

```
