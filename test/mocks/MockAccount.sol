// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BaseAccount} from "account-abstraction/core/BaseAccount.sol";

contract MockAccount is BaseAccount {
    enum AttackType {
        NONE,
        ATTACK_A,
        ATTACK_B,
        ATTACK_C
    }

    function execute(AttackType attackType) external {
        // Dummy implementation, nothing needed here.
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        console2.log("_validateSignature...");

        AttackType attackType = _decodeAttackType(userOp.callData);

        if (attackType == AttackType.ATTACK_A) {
            // Simulate ATTACK_A validation
        } else if (attackType == AttackType.ATTACK_B) {
            // Simulate ATTACK_B validation
        } else if (attackType == AttackType.ATTACK_C) {
            // Simulate ATTACK_C validation
        }

        return 0;
    }

    function _decodeAttackType(bytes calldata callData) private pure returns (AttackType) {
        require(callData.length >= 4 + 32, "Invalid callData length");

        // Skip the first 4 bytes (function selector) and read the next 32 bytes (enum value)
        uint256 attackTypeValue;
        assembly {
            attackTypeValue := calldataload(4)
        }

        // Convert the value to AttackType enum
        return AttackType(attackTypeValue);
    }

}



//// check invalid opcode
// if (block.timestamp < 1) {
//     return 0;
// }

// check out of gas
// bytes memory encodedFunctionCall = abi.encodeWithSignature("consumeGas()");
// (bool success, ) = address(dummy).call{gas: 10}(encodedFunctionCall);
// require(success, "failed GG");

// // check accessing extcode with address without code
// address zeroAddr = address(0);
// bytes32 result;
// assembly {
//     result := extcodehash(zeroAddr)
// }
// console2.logBytes32(result);

// check non-associated storage
// dummy.touchSlot();

// Default to Pass with returning zero
