// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {EntryPoint} from "account-abstraction/core/EntryPoint.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";

import {ERC4337Checker} from "../src/ERC4337Checker.sol";

import {MockAccount} from "./mocks/MockAccount.sol";
import {MockPaymaster} from "./mocks/MockPaymaster.sol";

contract ERC4337CheckerTest is Test {
    EntryPoint public entryPoint;
    MockAccount public mockAccount;
    MockPaymaster public mockPaymaster;
    ERC4337Checker public checker;

    function setUp() public {
        entryPoint = new EntryPoint();

        mockAccount = new MockAccount(entryPoint);
        vm.deal(address(mockAccount), 1 << 128); // give some funds to the mockAccount

        mockPaymaster = new MockPaymaster(IEntryPoint(entryPoint));
        vm.deal(address(mockPaymaster), 1 << 128); // give some funds to the mockAccount
        entryPoint.depositTo{value: 1 ether}(address(mockPaymaster));
        mockPaymaster.addStake{value: 2 ether}(1);

        checker = new ERC4337Checker();
    }

    function test_validationPass() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertTrue(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
    }

    function test_validationWithPaymasterPass() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );
        userOp.paymasterAndData = abi.encodePacked(mockPaymaster);

        assertTrue(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
    }

    function test_forbiddenOpCodeBlockTime() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_BLOCKTIME
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );

        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_outOfGas() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.OUT_OF_GAS
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_accessExtcodeWithContractNoCode() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_accessUnassociatedStorageSlot() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.TOUCH_UNASSOCIATED_STORAGE_SLOT
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_accessPaymasterStorageSlotWithoutStake_shouldfail() public {
        address mockAccountAddr = address(mockAccount);

        MockPaymaster noStakePaymaster = new MockPaymaster(IEntryPoint(entryPoint));
        vm.deal(address(noStakePaymaster), 1 << 128); // give some funds to the mockAccount
        entryPoint.depositTo{value: 1 ether}(address(noStakePaymaster));

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );
        userOp.paymasterAndData = abi.encodePacked(
            noStakePaymaster,
            abi.encode(MockPaymaster.AttackType.UseStorage)
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_validateBundleWithSingleUserOp() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = userOp;

        assertTrue(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
    }

    function test_validateBundleWithMultipleUserOps() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp1 = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        address mockAccount2Addr = address(new MockAccount(entryPoint));
        vm.deal(address(mockAccount2Addr), 1 << 128);
        UserOperation memory userOp2 = _getUnsignedOp(
            mockAccount2Addr,
            encodedCallData
        );


        UserOperation[] memory userOps = new UserOperation[](2);
        userOps[0] = userOp1;
        userOps[1] = userOp2;

        assertTrue(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
    }

    function test_duplicateStorageOnBundle() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.execute.selector,
            MockAccount.AttackType.NONE
        );

        UserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        UserOperation[] memory userOps = new UserOperation[](2);
        userOps[0] = userOp;
        userOps[1] = userOp; // duplicated, so storage will conflict

        assertFalse(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
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
