// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "account-abstraction/core/BasePaymaster.sol";
import {IEntryPointSimulations} from "account-abstraction/interfaces/IEntryPointSimulations.sol";

/**
 * test paymaster, that pays for everything, without any check.
 */
contract MockPaymaster is BasePaymaster {
    uint storedDummyMaxCost = 12345;

    enum AttackType {
        NONE,
        UseStorage
    }

    constructor(IEntryPointSimulations _entryPoint) BasePaymaster(_entryPoint) {}

    function _validatePaymasterUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 maxCost)
    internal virtual override view
    returns (bytes memory context, uint256 validationData) {
        AttackType attackType = _decodeAttackType(userOp.paymasterAndData);
        uint dummyMaxCost = 12345;
        if (attackType == AttackType.UseStorage) {
            // force accessing the storage
            dummyMaxCost = storedDummyMaxCost;
        }

        (userOp, userOpHash, maxCost);
        return ("", maxCost == 12345 ? 1 : 0);
    }

    function _decodeAttackType(bytes calldata paymasterAndData) private pure returns (AttackType) {
        // Convert the value to AttackType enum
        if (paymasterAndData.length <= 20) {
            return AttackType.NONE;
        }
        return abi.decode(paymasterAndData[20:], (AttackType));
    }

    function _validateEntryPointInterface(IEntryPoint _entryPoint) internal override {
        // Skip validation for testing
    }
}

