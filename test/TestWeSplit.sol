// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/OwnableProxy.sol";
import "../src/WeSplit.sol";
import "../src/Arith.sol";

contract TestWeSplit is Test {
    using Arith for uint256;

    WeSplit public weSplitImplementation;
    OwnableProxy public weSplitProxy;
    WeSplit public weSplit;
    bytes public constant emptyData = "";

    address user1 = address(123);
    address user2 = address(978);
    address DAI = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address receiver = address(444);
    address[] users = new address[](2);
    uint256[] weights;

    function setUp() public {
        weSplitImplementation = new WeSplit();
        weSplitProxy = new OwnableProxy(address(weSplitImplementation), emptyData);
        weSplit = WeSplit(address(weSplitProxy));

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

    function testUpgradeOnlyOwner() public {
        WeSplit newWeSplitImplementation = new WeSplit();
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        weSplit.upgradeTo(address(newWeSplitImplementation));
        vm.stopPrank();

        weSplit.upgradeTo(address(newWeSplitImplementation));

        weSplit.renounceOwnership();
        vm.expectRevert("Ownable: caller is not the owner");
        weSplit.upgradeTo(address(weSplitImplementation));
    }

    function testCreate() public {
        vm.prank(user1);
        uint256 splitId = weSplit.create(users);
        address[] memory participants = weSplit.participants(splitId);
        assertEq(participants.length, 2, "participants length");
        assertEq(participants[0], user1, "participant 0");
        assertEq(participants[1], user2, "participant 1");
    }

    function testInitialize() public {
        uint256 amount = 14 ether;
        vm.startPrank(user1);
        uint256 splitId = weSplit.create(users);
        weSplit.initialize(splitId, DAI, amount, receiver, weights);
        vm.stopPrank();

        assertEq(weSplit.token(splitId), DAI, "running token");
        assertEq(weSplit.amount(splitId), uint256(amount), "running amount");
        assertEq(weSplit.receiver(splitId), receiver, "running receiver");
    }

    function testPartialApproval() public {
        uint256 amount = 1 ether;
        vm.prank(user1);
        uint256 splitId = weSplit.createInitializeApprove(users, DAI, amount, receiver, weights);

        assertTrue(weSplit.approval(splitId, user1), "has approve");
        assertEq(IERC20(DAI).balanceOf(address(weSplit)), 0, "balance weSplit");
    }

    function testSend() public {
        uint256 amount = 3 ether + 1;

        vm.prank(user1);
        uint256 splitId = weSplit.create(users);

        // The following variables are set after initialize
        assertEq(weSplit.token(splitId), address(0), "token should not be set");
        assertEq(weSplit.amount(splitId), 0, "amount should be 0");
        assertEq(weSplit.receiver(splitId), address(0), "receiver should not be set");
        assertEq(weSplit.weights(splitId)[0], 0, "weights[0] should not be set");
        assertEq(weSplit.weights(splitId)[1], 0, "weights[1] should not be set");

        vm.prank(user1);
        weSplit.initializeApprove(splitId, DAI, amount, receiver, weights);

        uint256[] memory sWeights = weSplit.weights(splitId);
        assertEq(sWeights.length, 2, "length of weights");
        assertEq(sWeights[0], 1, "weight of 0");
        assertEq(sWeights[1], 1, "weight of 1");

        vm.prank(user2);
        weSplit.approve(splitId);

        uint256 balanceReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceWeSplit = IERC20(DAI).balanceOf(address(weSplit));

        assertEq(balanceReceiver, amount, "transferred amount");
        assertEq(balanceWeSplit, 2 * amount.divUp(2) - amount, "dust amount");
        // split amount is reset at the end of the function:
        assertEq(weSplit.amount(splitId), 0);

        // split properties will be overwritten/reset at the start of a new tx:
        assertEq(weSplit.approvalCount(splitId), 2, "approval count not reset");
        assertEq(weSplit.token(splitId), DAI, "token not reset");
        assertEq(weSplit.receiver(splitId), receiver, "receiver not reset");
        //
        vm.prank(user1);
        weSplit.initialize(splitId, USDC, amount / 4, address(1000), weights);
        //
        assertEq(weSplit.approvalCount(splitId), 0, "approval count reset");
        assertEq(weSplit.token(splitId), USDC, "token changed");
        assertEq(weSplit.receiver(splitId), address(1000), "receiver changed");
        assertEq(weSplit.amount(splitId), amount / 4, "amount changed");
    }

    function testTwoGroups() public {
        uint256 amount = 5 ether + 1;

        uint256 balanceReceiverBefore = IERC20(DAI).balanceOf(receiver);

        vm.prank(user1);
        uint256 firstSplitId = weSplit.createInitializeApprove(
            users,
            DAI,
            amount,
            receiver,
            weights
        );

        vm.prank(user2);
        uint256 secondSplitId = weSplit.createInitializeApprove(
            users,
            DAI,
            amount,
            receiver,
            weights
        );

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

    function testNotTransferable() public {
        uint256 amount = 6 * 1e6 + 1;

        address otherUser = address(111);

        address[] memory allUsers = new address[](users.length + 1);
        for (uint256 i; i < users.length; i++) allUsers[i] = users[i];
        allUsers[allUsers.length - 1] = otherUser;

        vm.prank(user1);
        uint256 firstSplitId = weSplit.createInitializeApprove(
            allUsers,
            DAI,
            amount,
            receiver,
            weights
        );
        address token = weSplit.token(firstSplitId);

        assertFalse(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "not approved");

        vm.prank(otherUser);
        weSplit.approve(firstSplitId);

        assertFalse(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "weSplit approved");

        vm.prank(otherUser);
        IERC20(token).approve(address(weSplit), type(uint256).max);

        assertFalse(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "token approved");

        deal(DAI, otherUser, amount);

        assertTrue(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "enough funds");
    }

    function testWeights() public {
        uint256 amount = 7 ether;
        uint256[] memory newWeights = new uint256[](2);
        newWeights[0] = 3;
        newWeights[1] = 4;
        vm.prank(user1);
        uint256 splitId = weSplit.createInitializeApprove(users, DAI, amount, receiver, newWeights);

        uint256[] memory sWeights = weSplit.weights(splitId);
        assertEq(sWeights.length, 2, "weights length");
        assertEq(sWeights[0], newWeights[0], "weight 0");
        assertEq(sWeights[1], newWeights[1], "weight 1");

        uint256 balanceBeforeUser1 = IERC20(DAI).balanceOf(user1);
        uint256 balanceBeforeUser2 = IERC20(DAI).balanceOf(user2);

        vm.prank(user2);
        weSplit.approve(splitId);

        uint256 balanceAfterReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceAfterUser1 = IERC20(DAI).balanceOf(user1);
        uint256 balanceAfterUser2 = IERC20(DAI).balanceOf(user2);

        assertEq(balanceAfterReceiver, amount, "transferred amount");
        assertEq(balanceBeforeUser1 - balanceAfterUser1, 3 ether, "balance user1");
        assertEq(balanceBeforeUser2 - balanceAfterUser2, 4 ether, "balance user2");
    }

    function testNoWeightsDefaultToOnes() public {
        uint256[] memory expectedWeights = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) expectedWeights[i] = 1;
        uint256[] memory emptyWeights;

        vm.prank(user1);
        uint256 splitId = weSplit.createInitializeApprove(
            users,
            DAI,
            1 ether,
            receiver,
            emptyWeights
        );

        assertEq(weSplit.weights(splitId), expectedWeights);
    }

    function testFailWrongWeights() public {
        uint256[] memory wrongWeights = new uint256[](3);

        vm.prank(user1);
        weSplit.createInitializeApprove(users, DAI, 1 ether, receiver, wrongWeights);
    }
}
