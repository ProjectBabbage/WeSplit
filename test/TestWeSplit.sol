// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/WeSplit.sol";
import "../src/Arith.sol";

contract TestWeSplit is Test {
    using Arith for uint256;

    WeSplit public weSplit;
    address user1 = address(123);
    address user2 = address(978);
    address DAI = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address receiver = address(444);
    address[] users = new address[](2);

    function setUp() public {
        weSplit = new WeSplit();
        users[0] = user1;
        users[1] = user2;
        for (uint256 i; i < users.length; i++) setUpUser(users[i]);
    }

    function setUpUser(address user) private {
        // Give users 1000 units of DAI & USDC
        deal(DAI, user, 1000 ether);
        deal(USDC, user, 1000 * 1e6);
        vm.startPrank(user);
        IERC20(DAI).approve(address(weSplit), type(uint256).max);
        IERC20(USDC).approve(address(weSplit), type(uint256).max);
        vm.stopPrank();
    }

    function testCreate() public {
        vm.prank(user1);
        uint256 splitId = weSplit.create(users);
        assertEq(weSplit.participantsLength(splitId), 2);
        assertEq(weSplit.participant(splitId, 0), user1);
        assertEq(weSplit.participant(splitId, 1), user2);
    }

    function testInitialize() public {
        uint256 amount = 14 ether;
        vm.startPrank(user1);
        uint256 splitId = weSplit.create(users);
        weSplit.initialize(splitId, DAI, amount, receiver);
        vm.stopPrank();

        assertEq(weSplit.token(splitId), DAI, "running token");
        assertEq(weSplit.amount(splitId), uint256(amount), "running amount");
        assertEq(weSplit.receiver(splitId), receiver, "running receiver");
    }

    function testPartialApproval() public {
        uint256 amount = 1 ether;
        vm.prank(user1);
        uint256 splitId = weSplit.createInitializeApprove(users, DAI, amount, receiver);

        assertTrue(weSplit.approval(splitId, user1), "has approve");
        assertEq(IERC20(DAI).balanceOf(address(weSplit)), amount / 2, "balance weSplit");
    }

    function testSend() public {
        uint256 amount = 3 ether + 1;
        vm.startPrank(user1);
        uint256 splitId = weSplit.create(users);
        assertEq(weSplit.token(splitId), address(0));
        weSplit.initializeApprove(splitId, DAI, amount, receiver);
        vm.stopPrank();

        vm.prank(user2);
        weSplit.approve(splitId);

        uint256 balanceReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceWeSplit = IERC20(DAI).balanceOf(address(weSplit));

        assertEq(balanceReceiver, amount, "transferred amount");
        assertEq(balanceWeSplit, 2 * amount.divUp(2) - amount, "dust amount");
        // split amount is reset at the end of the function:
        assertEq(weSplit.amount(splitId), 0);

        // split properties will be overwritten/reset at the start of a new tx:
        assertEq(weSplit.approvalCount(splitId), 2);
        assertEq(weSplit.token(splitId), DAI);
        assertEq(weSplit.receiver(splitId), receiver);
        //
        vm.prank(user1);
        weSplit.initialize(splitId, USDC, amount / 4, address(1000));
        //
        assertEq(weSplit.approvalCount(splitId), 0);
        assertEq(weSplit.token(splitId), USDC);
        assertEq(weSplit.receiver(splitId), address(1000));
        assertEq(weSplit.amount(splitId), amount / 4);
    }

    function testTwoGroups() public {
        uint256 amount = 5 ether + 1;

        uint256 balanceReceiverBefore = IERC20(DAI).balanceOf(receiver);

        vm.prank(user1);
        uint256 firstSplitId = weSplit.createInitializeApprove(users, DAI, amount, receiver);

        vm.prank(user2);
        uint256 secondSplitId = weSplit.createInitializeApprove(users, DAI, amount, receiver);

        assertFalse(firstSplitId == secondSplitId, "split ids should be different");

        vm.prank(user1);
        weSplit.approve(secondSplitId);

        vm.prank(user2);
        weSplit.approve(firstSplitId);

        uint256 balanceReceiverAfter = IERC20(DAI).balanceOf(receiver);

        assertEq(
            balanceReceiverAfter - balanceReceiverBefore,
            2 * amount,
            "receiver did not receive its exact share"
        );
    }
}
