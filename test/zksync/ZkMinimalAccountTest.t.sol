// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from "../../lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";



contract ZkMinimalAccountTest is Test {

    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
    address randomuser = makeAddr("randomuser");

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        usdc = new ERC20Mock();
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