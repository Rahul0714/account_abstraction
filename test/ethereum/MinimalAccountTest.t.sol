// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {ERC20Mock} from "../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IEntryPoint} from "../../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {SIG_VALIDATION_SUCCESS} from "../../lib/account-abstraction/contracts/core/Helpers.sol";

import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "../../script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {SendPackedUserOp, PackedUserOperation} from "../../script/SendPackedUserOp.s.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount private minimalAccount;
    HelperConfig private helperConfig;
    ERC20Mock private usdc;
    SendPackedUserOp private sendPackedUserOp;

    uint256 private constant AMOUNT = 1e18;

    address private randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimalAccount deployMinimalAccount = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployMinimalAccount
            .deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(randomUser), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            randomUser,
            AMOUNT
        );
        vm.prank(randomUser);
        vm.expectRevert();
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );
        bytes32 userOperationHash = IEntryPoint(
            helperConfig.getConfig().entryPoint
        ).getUserOpHash(packedUserOp);

        address acutalSigner = ECDSA.recover(
            userOperationHash.toEthSignedMessageHash(),
            packedUserOp.signature
        );

        assertEq(acutalSigner, minimalAccount.owner());
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );
        bytes32 userOperationHash = IEntryPoint(
            helperConfig.getConfig().entryPoint
        ).getUserOpHash(packedUserOp);

        uint256 missingAccountFunds = 1e18;

        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(
            packedUserOp,
            userOperationHash,
            missingAccountFunds
        );
        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testCanEntryPointExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        // assertEq(usdc.balanceOf(randomUser, 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector,
            address(minimalAccount),
            AMOUNT
        );
        bytes memory executeCallData = abi.encodeWithSelector(
            MinimalAccount.execute.selector,
            dest,
            value,
            functionData
        );
        PackedUserOperation memory packedUserOp = sendPackedUserOp
            .generateSignedUserOperation(
                executeCallData,
                helperConfig.getConfig(),
                address(minimalAccount)
            );

        vm.deal(address(minimalAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(randomUser);
        IEntryPoint(
            helperConfig.getConfig().entryPoint
        ).handleOps(ops,payable(randomUser));

        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);        
    }
}
