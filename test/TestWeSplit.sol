// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";

import "src/WeSplitProxy.sol";
import "src/WeSplit.sol";
import "src/Arith.sol";

contract TestWeSplit is Test {
    using Arith for uint256;

    WeSplit public weSplitImplementation;
    WeSplitProxy public weSplitProxy;
    WeSplit public weSplit;
    bytes public constant emptyData = "";
    address user1;
    address user2;
    address user3;
    address otherUser;
    address receiver;
    address DAI = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address[] allUsers = new address[](5);
    address[] users = new address[](2);
    uint256[] weights;

    function setUp() public {
        weSplitImplementation = new WeSplit();
        weSplitProxy = new WeSplitProxy(address(weSplitImplementation), emptyData);
        weSplit = WeSplit(address(weSplitProxy));

        for (uint256 i; i < allUsers.length; i++) {
            allUsers[i] = address(uint160(100 + i));
            setUpUser(allUsers[i]);
        }
        user1 = allUsers[0];
        user2 = allUsers[1];
        user3 = allUsers[2];

        otherUser = address(uint160(100 + allUsers.length));
        receiver = address(uint160(100 + allUsers.length + 1));

        users[0] = user1;
        users[1] = user2;
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
        assertEq(weSplit.owner(), address(this), "owner is the test contract");
        WeSplit newWeSplitImplementation = new WeSplit();
        vm.startPrank(user1);
        vm.expectRevert("Ownable: caller is not the owner");
        weSplit.upgradeTo(address(newWeSplitImplementation));
        vm.stopPrank();

        weSplit.upgradeTo(address(newWeSplitImplementation));

        weSplit.renounceOwnership();
        assertEq(weSplit.owner(), address(0), "no owner anymore");
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

        address[] memory splitUsers = new address[](3);
        splitUsers[0] = user1;
        splitUsers[1] = user2;
        splitUsers[2] = otherUser;

        vm.prank(user1);
        uint256 firstSplitId = weSplit.createInitializeApprove(
            splitUsers,
            DAI,
            amount,
            receiver,
            weights
        );

        assertFalse(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "not approved");

        vm.prank(otherUser);
        weSplit.approve(firstSplitId);

        assertFalse(weSplit.checkTransferabilityUser(firstSplitId, otherUser), "weSplit approved");

        vm.prank(otherUser);
        IERC20(DAI).approve(address(weSplit), type(uint256).max);

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

    function testCreateFromScratch() public {
        uint256 amount = 9 ether;

        address[] memory splitUsers = new address[](1);
        splitUsers[0] = user1;

        vm.startPrank(user1);
        uint256 splitId = weSplit.create(splitUsers);
        weSplit.addParticipant(splitId, user2);
        weSplit.addParticipant(splitId, user3);
        assertEq(weSplit.rankParticipant(splitId, user1), 1, "user1 is at rank 1");
        assertEq(weSplit.rankParticipant(splitId, user2), 2, "user3 is at rank 2");
        assertEq(weSplit.rankParticipant(splitId, user3), 3, "user2 is at rank 3");

        uint256 balanceUser1Start = IERC20(DAI).balanceOf(user1);
        uint256 balanceUser2Start = IERC20(DAI).balanceOf(user2);
        uint256 balanceUser3Start = IERC20(DAI).balanceOf(user3);

        uint256[] memory firstWeights = new uint256[](3);
        firstWeights[0] = 3;
        firstWeights[1] = 4;
        firstWeights[2] = 2;
        weSplit.initializeApprove(splitId, DAI, amount, receiver, firstWeights);
        vm.stopPrank();

        vm.prank(user2);
        weSplit.approve(splitId);
        vm.prank(user3);
        weSplit.approve(splitId);

        uint256 balanceUser1Middle = IERC20(DAI).balanceOf(user1);
        uint256 balanceUser2Middle = IERC20(DAI).balanceOf(user2);
        uint256 balanceUser3Middle = IERC20(DAI).balanceOf(user3);

        assertEq(
            balanceUser1Start - balanceUser1Middle,
            3 ether,
            "balance user 1 first transaction"
        );
        assertEq(
            balanceUser2Start - balanceUser2Middle,
            4 ether,
            "balance user 2 first transaction"
        );
        assertEq(
            balanceUser3Start - balanceUser3Middle,
            2 ether,
            "balance user 3 first transaction"
        );

        vm.prank(user2);
        weSplit.removeParticipant(splitId, user1);
        assertEq(weSplit.rankParticipant(splitId, user1), 0, "user1 is not in the split anymore");
        assertEq(weSplit.rankParticipant(splitId, user2), 2, "user2 is now second");
        assertEq(weSplit.rankParticipant(splitId, user3), 1, "user3 is now first");
        uint256[] memory secondWeights = new uint256[](2);
        secondWeights[0] = 5;
        secondWeights[1] = 4;
        vm.prank(user2);
        weSplit.initializeApprove(splitId, DAI, amount, receiver, secondWeights);
        vm.prank(user3);
        weSplit.approve(splitId);

        uint256 balanceUser2End = IERC20(DAI).balanceOf(user2);
        uint256 balanceUser3End = IERC20(DAI).balanceOf(user3);

        assertEq(
            balanceUser2Middle - balanceUser2End,
            4 ether,
            "balance user 2 second transaction"
        );
        assertEq(
            balanceUser3Middle - balanceUser3End,
            5 ether,
            "balance user 3 second transaction"
        );
    }
}
