// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {EntryPointSimulations} from "account-abstraction/core/EntryPointSimulations.sol";
import {IEntryPointSimulations} from "account-abstraction/interfaces/IEntryPointSimulations.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";

import {ERC4337Checker} from "../src/ERC4337Checker.sol";

import {MockAccount} from "./mocks/MockAccount.sol";
import {MockPaymaster} from "./mocks/MockPaymaster.sol";

contract ERC4337CheckerTest is Test {
    EntryPointSimulations public entryPoint;
    MockAccount public mockAccount;
    MockPaymaster public mockPaymaster;
    ERC4337Checker public checker;

    function setUp() public {
        entryPoint = new EntryPointSimulations();

        mockAccount = new MockAccount(entryPoint);
        vm.deal(address(mockAccount), 1 << 128); // give some funds to the mockAccount

        mockPaymaster = new MockPaymaster(entryPoint);
        vm.deal(address(mockPaymaster), 1 << 128); // give some funds to the mockAccount
        entryPoint.depositTo{value: 1 ether}(address(mockPaymaster));
        entryPoint.depositTo{value: 1 ether}(address(mockAccount));
        mockPaymaster.addStake{value: 2 ether}(1);

        checker = new ERC4337Checker();
    }

    function test_validationPass() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_BLOCKTIME
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );

        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function test_forbiddenOpCodeGasPrice() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_GASPRICE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        checker.printFailureLogs();
    }

    function test_forbiddenOpCodeGasLimit() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_GASLIMIT
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        checker.printFailureLogs();
    }

    function test_forbiddenOpCodeCoinbase() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_COINBASE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        checker.printFailureLogs();
    }

    function test_forbiddenOpCodeOrigin() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_ORIGIN
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        checker.printFailureLogs();
    }

    function test_forbiddenOpCodeInvalid() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.FORBIDDEN_OPCODE_INVALID
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        // The INVALID opcode (0xFE) is executed in a try-catch block
        // This allows the debug trace to capture it, and the checker should detect it
        assertFalse(
            checker.simulateAndVerifyUserOp(vm, userOp, entryPoint)
        );
        checker.printFailureLogs();
    }

    function test_outOfGas() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.OUT_OF_GAS
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.TOUCH_UNASSOCIATED_STORAGE_SLOT
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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

        MockPaymaster noStakePaymaster = new MockPaymaster(entryPoint);
        vm.deal(address(noStakePaymaster), 1 << 128); // give some funds to the mockAccount
        entryPoint.depositTo{value: 1 ether}(address(noStakePaymaster));

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
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
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        assertTrue(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
    }

    function test_validateBundleWithMultipleUserOps() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp1 = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        address mockAccount2Addr = address(new MockAccount(entryPoint));
        vm.deal(address(mockAccount2Addr), 1 << 128);
        PackedUserOperation memory userOp2 = _getUnsignedOp(
            mockAccount2Addr,
            encodedCallData
        );


        PackedUserOperation[] memory userOps = new PackedUserOperation[](2);
        userOps[0] = userOp1;
        userOps[1] = userOp2;

        assertTrue(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
    }

    function test_duplicateStorageOnBundle() public {
        address mockAccountAddr = address(mockAccount);

        bytes memory encodedCallData = abi.encodeWithSelector(
            MockAccount.executeAttack.selector,
            MockAccount.AttackType.NONE
        );

        PackedUserOperation memory userOp = _getUnsignedOp(
            mockAccountAddr,
            encodedCallData
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](2);
        userOps[0] = userOp;
        userOps[1] = userOp; // duplicated, so storage will conflict

        assertFalse(
            checker.simulateAndVerifyBundle(vm, userOps, entryPoint)
        );
        // output the failure log, can be seen when runnning the test with -vvv
        checker.printFailureLogs();
    }

    function _getUnsignedOp(address target, bytes memory innerCallData) private pure returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: target,
            nonce: 0, // Adjust nonce as required
            initCode: "",
            callData: innerCallData,
            accountGasLimits: bytes32((uint256(5_000_000) << 128) | uint256(30_000_000)),
            preVerificationGas: 1 << 24,
            gasFees: bytes32((uint256(5_000_000) << 128) | uint256(30_000_000)),
            paymasterAndData: "",
            signature: ""
        });
    }
}