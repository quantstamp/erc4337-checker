// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";
import {UserOperation} from "account-abstraction/interfaces/UserOperation.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

import "forge-std/console2.sol";


contract InvalidActions {
    uint invalidSlotAccess;

    // Function to intentionally consume a lot of gas
    function consumeGas() public pure {
        require(true, "not reverting");
        console2.log("consumeGas");
    }

    function touchInvalidSlot() public view {
        console2.log("consumeGas: ", invalidSlotAccess);
    }

    // Function that triggers the INVALID opcode (0xFE)
    function triggerInvalidOpcode() public pure {
        assembly {
            invalid()
        }
    }
}

contract MockAccount is BaseAccount {
    enum AttackType {
        NONE,
        FORBIDDEN_OPCODE_BLOCKTIME,
        OUT_OF_GAS,
        ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE,
        TOUCH_UNASSOCIATED_STORAGE_SLOT,
        FORBIDDEN_OPCODE_GASPRICE,
        FORBIDDEN_OPCODE_GASLIMIT,
        FORBIDDEN_OPCODE_COINBASE,
        FORBIDDEN_OPCODE_ORIGIN,
        FORBIDDEN_OPCODE_INVALID,
        FORBIDDEN_OPCODE_CREATE
    }

    IEntryPoint private _entryPoint;
    InvalidActions private invalidActions;

    constructor(IEntryPoint entryPoint_) {
        _entryPoint = entryPoint_;
        invalidActions = new InvalidActions();
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function execute(AttackType /*attackType*/) external pure {
        console2.log("dummy execute");
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 /*userOpHash*/)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        AttackType attackType = _decodeAttackType(userOp.callData);
        if (attackType == AttackType.FORBIDDEN_OPCODE_BLOCKTIME) {
            // forbidden opcode: TIMESTAMP
            if (block.timestamp < 1) {
                return 0;
            }
        } else if (attackType == AttackType.OUT_OF_GAS) {
            bytes memory encodedFunctionCall = abi.encodeWithSignature("consumeGas()", "");
            uint notEnoughGas = 10;
            (bool success, ) = address(invalidActions).call{gas: notEnoughGas}(encodedFunctionCall);
            require(!success, "it should error out of gas");
        } else if (attackType == AttackType.ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE) {
            address zeroAddr = address(0);
            bytes32 result;
            assembly {
                result := extcodehash(zeroAddr)
            }

            console2.logBytes32(result);
            require(result == bytes32(0), "The EXTCODEHASH of non-existent account should be 0");
        } else if (attackType == AttackType.TOUCH_UNASSOCIATED_STORAGE_SLOT) {
            invalidActions.touchInvalidSlot();
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_GASPRICE) {
            // forbidden opcode: GASPRICE
            uint256 gasPrice = tx.gasprice;
            console2.log("gasprice:", gasPrice);
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_GASLIMIT) {
            // forbidden opcode: GASLIMIT
            uint256 gasLimit = block.gaslimit;
            console2.log("gaslimit:", gasLimit);
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_COINBASE) {
            // forbidden opcode: COINBASE
            address coinbase = block.coinbase;
            console2.log("coinbase:", coinbase);
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_ORIGIN) {
            // forbidden opcode: ORIGIN
            address origin = tx.origin;
            console2.log("origin:", origin);
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_INVALID) {
            // forbidden opcode: INVALID (0xFE)
            // We use try-catch to prevent immediate revert, allowing the debug trace to capture the opcode
            try invalidActions.triggerInvalidOpcode() {
                // This should never execute as invalid() always reverts
                console2.log("Invalid opcode did not revert (unexpected)");
            } catch {
                // The invalid opcode was executed and caught
                console2.log("Invalid opcode caught in try-catch");
            }
        } else if (attackType == AttackType.FORBIDDEN_OPCODE_CREATE){
            address demoAddress = address(new InvalidActions());
            console2.log("New contract", demoAddress);

        }

        return 0;
    }

    function _decodeAttackType(bytes calldata callData) private pure returns (AttackType) {
        // Ensure the data is long enough to contain both the function selector and the enum argument
        require(callData.length >= 4 + 32, "Invalid encodedCallData length");

        require(bytes4(callData[:4]) == this.execute.selector, "Invalid function selector");

        // Convert the value to AttackType enum
        return AttackType(uint256(bytes32(callData[4:])));
    }
}
