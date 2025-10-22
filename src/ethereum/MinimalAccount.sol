// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {IAccount} from "../../lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "../../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {SIG_VALIDATION_FAILED,SIG_VALIDATION_SUCCESS} from "../../lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "../../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";


contract MinimalAccount is Ownable {

    error MinimaAccount__NotFromEntryPoint();
    error MinimaAccount__NotFromEntryPointOrOwner();
    error MinimaAccount__CallFailed(bytes result);


    IEntryPoint private immutable i_entryPoint;



    modifier requireFromEntryPoint(){
        if(msg.sender != address(i_entryPoint)){
            revert MinimaAccount__NotFromEntryPoint();
        }
        _;
    }
    modifier requireFromEntryPointOrOwner(){
        if(msg.sender != address(i_entryPoint) && msg.sender != owner()){
            revert MinimaAccount__NotFromEntryPointOrOwner();
        }
        _;
    }


    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable{}

    // so first thing we need to do is validate the signature.
    // a signature is valid if its the contract owner,
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external requireFromEntryPoint returns (uint256 validationData) {

        validationData = _validateSignature(userOp,userOpHash);
        // here we pay the entry point contract.
        _payPrefund(missingAccountFunds);
    }

    // so userOpHash is not in the correct hash version so we need to convert it in the real hash version
    function _validateSignature(PackedUserOperation calldata userOp,bytes32 userOpHash) internal view returns(uint256){
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash,userOp.signature);
        if(signer != owner()){
            return SIG_VALIDATION_FAILED;
        }
            return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if(missingAccountFunds != 0){
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    function execute(address dest,uint256 value,bytes calldata functionData) external requireFromEntryPointOrOwner{
        // here next lline says we can send eth as well as call function if there is functiondata then its calling
        // function otherwise its sending transaction somewhere.
        (bool success,bytes memory result) = dest.call{value: value}(functionData);
        if(!success){
            revert MinimaAccount__CallFailed(result);
        }
    }



















    function getEntryPoint() external view returns(address){
        return address(i_entryPoint);
    }

}