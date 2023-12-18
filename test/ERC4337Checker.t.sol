// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {ERC4337Checker} from "../src/ERC4337Checker.sol";

import {MockAccount} from "./mocks/MockAccount.sol";

contract CounterTest is Test {
    EntryPoint entryPoint;
    MockAccount mockAccount;

    function setUp() public {
        entryPoint = new EntryPoint();
        mockAccount = new MockAccount();
    }

    function testExecuteAttackType() public {
        // Assuming LightAccount is deployed at 'lightAccountAddress'
        address mockAccountAddr = address(mockAccount);

        // Encode a call to LightAccount.execute with a specific AttackType
        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.ATTACK_A // Example: using ATTACK_A
        );

        // Create a UserOperation targeting the LightAccount contract
        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        try entryPoint.simulateValidation(userOp) {
            // the simulateValidation function will always revert.
            // in this test, we do not really care if it is revert in an expected output or not.
        } catch Error(string memory reason) {
            // This is executed if a revert was thrown with a reason
            console2.log("ERR Str: ", reason);
        } catch (bytes memory reason) {
            if (reason.length < 4 && bytes4(reason) != ValidationResult.selector) {
                assertTrue(false, "unexpected errored out");
            }
        }

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertTrue(
            EIP4337Check.validateUserOp(steps, userOp, entryPoint)
        );
    }

    // Helper function to get an unsigned UserOperation
    function _getUnsignedOp(address target, bytes memory innerCallData) internal view returns (UserOperation memory) {
        return UserOperation({
            sender: target,
            nonce: 0, // Adjust nonce as required
            initCode: "",
            callData: innerCallData,
            callGasLimit: 1 << 24,
            verificationGasLimit: 1 << 24,
            preVerificationGas: 1 << 24,
            maxFeePerGas: 1 << 8,
            maxPriorityFeePerGas: 1 << 8,
            paymasterAndData: "",
            signature: ""
        });
    }

}
