// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./DeployMinimal.s.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract DeployMinimal is Script {

    function run() external {}

    function generatedSignedUserOperation(bytes calldata callData, HelperConfig.NetworkConfig memory config)
        public view
        returns (PackedUserOperation memory)
    {
        uint256 nonce = vm.getNonce(config.account);
        // 1. generate the unsigned data.
        PackedUserOperation memory userOp = generatedUnsignedUserOperation(callData, config.account, nonce);
        // 2. get the userOp hash.
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        // now convert it to ethsignedMessagehash
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        // 3. Sign it.
        (uint8 v,bytes32 r,bytes32 s) = vm.sign(config.account,digest);
        userOp.signature = abi.encodePacked(r,s,v); //note the order.
        return(userOp);

    }

    function generatedUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            // here the next line just packs both uint128 in 2 diff slots as it save gas.
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
