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
}

contract MockAccount is BaseAccount {
    enum AttackType {
        NONE,
        FORBIDDEN_OPCODE_BLOCKTIME,
        OUT_OF_GAS,
        ACCESS_EXTCODE_WITH_ADDRESS_NO_CODE,
        TOUCH_UNASSOCIATED_STORAGE_SLOT
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
        console2.log("[_validateSignature] decoded attack type: ", uint8(attackType));
        if (attackType == AttackType.FORBIDDEN_OPCODE_BLOCKTIME) {
            // forbidden opcode
            if (block.timestamp < 1) {
                return 0;
            }
        } else if (attackType == AttackType.OUT_OF_GAS) {
            bytes memory encodedFunctionCall = abi.encodeWithSignature("consumeGas()", "");
            uint notEnoughGas = 10;
            address(invalidActions).call{gas: notEnoughGas}(encodedFunctionCall);
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
