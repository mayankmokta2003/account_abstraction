// SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "../script/DeployMinimal.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    DeployMinimal deployer;
    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    ERC20Mock usdc;
    uint256 amount = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        deployer = new DeployMinimal();
        (helperConfig, minimalAccount) = deployer.deployMinimalAccount();
        usdc = new ERC20Mock();
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

    // here for this function test we will crete sendPacketUserOp in script as the fn validateUserOp has
    // PackedUserOperation in parameter so we need to do a lot
}
