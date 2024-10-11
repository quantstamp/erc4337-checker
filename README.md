# ERC4337-Checker

This is a tool to help validate the ERC4337 limitations on forbidden opcodes and accessing disallowed storage. For detailed specification, please read: [EIP4337 spec doc](https://eips.ethereum.org/EIPS/eip-4337#specification).

This is a library tool intended to be used as a dependency and imported to use in the Forge tests.

The tool is only compatible with the reference implementation of account abstraction: https://github.com/eth-infinitism/account-abstraction/. Currently, this tool is tested with the `v0.6.0` version of the `account-abstraction` repo.

To use this tool, you will need to use a Foundry version after `nightly-f79c53c4e41958809ee1f3473466f184bb34c195`, which includes the `startDebugTraceRecording` and `stopDebugTraceRecording` cheatcodes. Running `foundryup` should get you the latest nightly versions that include the cheatcodes.

Also, you will need to use `forge-std` after commit `4f57c59` (see: [link](https://github.com/foundry-rs/forge-std/commit/4f57c59f066a03d13de8c65bb34fca8247f5fcb2)).
You can install the master branch to get the interface:
```sh
forge install foundry-rs/forge-std@master
```
(Note: at the time of this README, the latest forge-std version is v1.9.3, which does not include the change yet. However, it is likely that all releases afterward should have it included. If there is a newer release, there is no need to install with the master tag.)

After the `forge` and `forge-std` setup, you can add this repository to your target repo:
```sh
forge install quantstamp/erc4337-checker
```

Now, you can start writing tests leveraging this ERC4337 checker! The tool supports validation on both userOp and bundle levels.

After providing the test, **remember to run it with the `-vvv` flag**. The cheatcode implementation requires a "tracer" to be turned on and, unfortunately, there are no other flags to enable the tracer when initiated (see: [PR discussion](https://github.com/foundry-rs/foundry/pull/8571#discussion_r1744059244)) at this time. There might be follow-up efforts to enable new flags, though (see: [comment](https://github.com/foundry-rs/foundry/pull/8571#pullrequestreview-2347884799)).

```sh
forge test -vvv
```

### Sample Tests

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

        // (Optional) To debug, this will output all failure logs telling what rules are violated.
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
