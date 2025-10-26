// SPDX-License-Identifier:MIT

// in foundry.toml instead of is-system = true write this --system-mode = true when working with nonce while validating

pragma solidity ^0.8.18;
import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/INonceHolder.sol";
import {
    MemoryTransactionHelper
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Utils} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/Utils.sol";

/**
 * Lifecycle of a type 113 (0x71) transaction
 * msg.sender is the bootloader system contract
 *
 * Phase 1 Validation
 * 1. The user sends the transaction to the "zkSync API client" (sort of a "light node")
 * 2. The zkSync API client checks to see the the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update the nonce
 * 4. The zkSync API client checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 Execution
 * 7. The zkSync API client passes the validated transaction to the main node / sequencer (as of today, they are the same)
 * 8. The main node calls executeTransaction
 * 9. If a paymaster was used, the postTransaction is called
 */

contract ZkMinimalAccount is IAccount, Ownable {
    // whenever we send a tx113 tx msg.sender will always be the the bootloader system contract

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__FailedToPay();

    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if ((msg.sender != BOOTLOADER_FORMAL_ADDRESS) && (msg.sender != owner())) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable{}

    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable
        requireFromBootLoader
        returns (bytes4 magic)
    {
       magic =  _validateTransaction(_transaction);
        
    }



    function executeTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable requireFromBootLoaderOrOwner {
        _executeTransaction(_transaction);
        }



    function executeTransactionFromOutside(Transaction memory _transaction) external payable { 
        bytes4 magic =  _validateTransaction(_transaction);
        _executeTransaction(_transaction);
    }




    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction memory _transaction)
        external
        payable {
            (bool success) = MemoryTransactionHelper.payToTheBootloader(_transaction);
            if(!success){
                revert ZkMinimalAccount__FailedToPay();
            }
        }



    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable {}



        function _validateTransaction(Transaction memory _transaction) internal returns(bytes4 magic) {
            // 1.must increase the nonce
            if(block.chainid != 300){
            }else{
            SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT), // address of nonce
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );
            }
        // check for fee to pay
        uint256 totalRequiredBalance = MemoryTransactionHelper.totalRequiredBalance(_transaction);
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }
        // must validate the transaction with signaure.
        bytes32 resultHash = MemoryTransactionHelper.encodeHash(_transaction);
        // bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(resultHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
        }






        function _executeTransaction(Transaction memory _transaction) internal {

        address to = address(uint160(_transaction.to));
        // we will make value uint128 as we might use value as a system contract call and it takes uint128
        // zksync interally supports 128bits value and we could have done smt like uint128(_transaction.value)
        // but if it was bigger that 128 bits then it would return half the value so we used this fn because
        // this fn says revert if value is larger thats 128 bits.
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        // if to was calling a system contract then 
        if(to == address(DEPLOYER_SYSTEM_CONTRACT)){
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas,to,value,data);
        }else{
        // call the function in basic low level
        bool success;
        assembly {
            success := call(gas(),to,value, add(data,0x20),mload(data),0,0)
        }
        if(!success){
            revert ZkMinimalAccount__ExecutionFailed();
        }
        }
        }








}
