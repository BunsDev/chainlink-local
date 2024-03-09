// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {BasicTokenSender} from "../../../src/test/ccip/BasicTokenSender.sol";
import {CCIPLocalSimulator, Router, BurnMintERC677Helper, Client} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";

contract PayWithNativeTest is Test {
    CCIPLocalSimulator public ccipLocalSimulator;
    BasicTokenSender public sender;
    uint64 chainSelector;
    BurnMintERC677Helper ccipBnM;
    Router sourceRouter;
    address alice;
    address bob;

    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector_,
            Router sourceRouter_,
            ,
            ,
            ,
            BurnMintERC677Helper ccipBnM_,

        ) = ccipLocalSimulator.DOCUMENTATION();

        sender = new BasicTokenSender(address(sourceRouter_));

        chainSelector = chainSelector_;
        ccipBnM = ccipBnM_;
        sourceRouter = sourceRouter_;

        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    function test_shouldPayInNativeCoin() external {
        vm.startPrank(alice);

        ccipBnM.drip(alice);
        uint256 amountToSend = 100;

        Client.EVMTokenAmount[]
            memory tokensToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenToSend = Client.EVMTokenAmount({
            token: address(ccipBnM),
            amount: amountToSend
        });
        tokensToSendDetails[0] = tokenToSend;

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(alice),
            data: "",
            tokenAmounts: tokensToSendDetails,
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = sourceRouter.getFee(chainSelector, message);

        uint256 balanceOfAliceBefore = ccipBnM.balanceOf(alice);
        uint256 balanceOfBobBefore = ccipBnM.balanceOf(bob);

        ccipBnM.increaseApproval(address(sender), amountToSend);
        assertEq(ccipBnM.allowance(alice, address(sender)), amountToSend);

        sender.send{value: fee}(chainSelector, bob, tokensToSendDetails);

        uint256 balanceOfAliceAfter = ccipBnM.balanceOf(alice);
        uint256 balanceOfBobAfter = ccipBnM.balanceOf(bob);
        assertEq(balanceOfAliceAfter, balanceOfAliceBefore - amountToSend);
        assertEq(balanceOfBobAfter, balanceOfBobBefore + amountToSend);

        vm.stopPrank();
    }
}
