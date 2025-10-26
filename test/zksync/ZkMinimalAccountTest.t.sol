// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    MemoryTransactionHelper
} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";


contract ZkMinimalAccountTest is Test {

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address randomuser = makeAddr("randomuser");
   
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(ANVIL_DEFAULT_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount),AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public{
        address to = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(usdc.mint.selector,address(minimalAccount),AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(address(minimalAccount.owner()),113,to,value,functionData);
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32,EMPTY_BYTES32,transaction);
        assertEq(usdc.balanceOf(address(minimalAccount)),AMOUNT);
    }


    function testRandomOwnerCannotExecuteCommands() public{
        address to = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encode(usdc.mint.selector,address(minimalAccount),AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(randomuser,113,to,value,functionData);
        vm.prank(randomuser);
        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootLoaderOrOwner.selector);
        minimalAccount.executeTransaction(EMPTY_BYTES32,EMPTY_BYTES32,transaction);
    }



    function testZkValidateTransaction() public {
        // Arrange
        address to = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector,address(minimalAccount),AMOUNT);
        Transaction memory transaction = _createUnsignedTransaction(address(minimalAccount.owner()),113,to,value,functionData);
        transaction = _signFunction(transaction);
        // Act
        // vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        (bytes4 magic) = minimalAccount.validateTransaction(EMPTY_BYTES32,EMPTY_BYTES32,transaction);
        // Assert
        assertEq(magic,ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }





    function _signFunction(Transaction memory transaction) internal view returns (Transaction memory) {
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);
        uint8 v; bytes32 r; bytes32 s;
        // theres bug in zksync that you actual account doesnot work here as owner so we use anvil keys
         uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        (v,r,s) = vm.sign(ANVIL_DEFAULT_KEY,unsignedTransactionHash);
        // transaction.signature = abi.encodePacked(r,s,v);
        // or we can do like
        Transaction memory signedTransaction = transaction;
        signedTransaction.signature = abi.encodePacked(r,s,v);
        return signedTransaction;
    }




    function _createUnsignedTransaction(address from,uint256 transactionType,address to,uint256 value,bytes memory data) internal view returns (Transaction memory){
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0),uint256(0),uint256(0),uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }






}