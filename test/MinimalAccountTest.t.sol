// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendpackedUserOp} from "../script/SendPackedUserOp.s.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {PackedUserOperation} from "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";



contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;
    DeployMinimal deployer;
    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    uint256 amount = 1e18;
    address randomUser = makeAddr("randomUser");
    SendpackedUserOp sendpackedUserOp;

    function setUp() public {
        deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendpackedUserOp = new SendpackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {


        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), amount);
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        assertEq(usdc.balanceOf(address(minimalAccount)), amount);
    }

    function testOnlyOwnerCanExecuteCommands() public {


        address dest = address(usdc);
        uint256 value = 0;
        bytes memory func = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), amount);
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimaAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, func);
    }

    // here we are actually testing our sendPackedUserOps script file
    function testValidationOfUserOps() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory func = abi.encodeWithSelector(usdc.mint.selector,address(minimalAccount),amount);
        // now in order to send this to our contract we again encode this whole data and execute function
        // itss like we are forwarding a call here.
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector,dest,value,func);
        PackedUserOperation memory packedUserOp = sendpackedUserOp.generatedSignedUserOperation(executeCallData,helperConfig.getConfig());
        // lets hash this as well
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(),packedUserOp.signature);

        // Assert
        assertEq(actualSigner,minimalAccount.owner());

    }

    // here for this function test we will crete sendPacketUserOp in script as the fn validateUserOp has
    // PackedUserOperation in parameter so we need to do a lot
}
