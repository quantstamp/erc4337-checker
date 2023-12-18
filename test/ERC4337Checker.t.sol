// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

import {ERC4337Checker} from "../src/ERC4337Checker.sol";

import {MockAccount} from "./mocks/MockAccount.sol";

contract ERC4337CheckerTest is Test {
    EntryPoint public entryPoint;
    MockAccount public mockAccount;

    function setUp() public {
        entryPoint = new EntryPoint();
        mockAccount = new MockAccount(entryPoint);
        vm.deal(address(mockAccount), 1 << 128);
    }

    function testValidationPass() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        simulateValidation(userOp);

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertTrue(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }

    function testForbiddenOpCodeBlockTime() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_BLOCKTIME
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        simulateValidation(userOp);

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertFalse(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }

    function testOutOfGas() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.OUT_OF_GAS
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        simulateValidation(userOp);

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertFalse(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }

    function testAccessExtcodeWithContractNoCode() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        simulateValidation(userOp);

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertFalse(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }

    function testAccessUnassociatedStorageSlot() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.TOUCH_UNASSOCIATED_STORAGE_SLOT
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        vm.startDebugTraceRecording();

        simulateValidation(userOp);

        Vm.DebugStep[] memory steps = vm.stopAndReturnDebugTraceRecording();

        assertFalse(
            ERC4337Checker.validateUserOp(steps, userOp, entryPoint)
        );
    }


    function simulateValidation(UserOperation memory userOp) private {
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

    function _getUnsignedOp(address target, bytes memory innerCallData) private pure returns (UserOperation memory) {
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
