// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "../src/Spleth.sol";
import "../src/Arith.sol";

contract TestSpleth is Test {
    using Arith for uint256;

    Spleth public spleth;
    address user1 = address(123);
    address user2 = address(978);
    address DAI = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    address USDC = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    address receiver = address(444);
    address[] users = new address[](2);

    function setUp() public {
        spleth = new Spleth();
        users[0] = user1;
        users[1] = user2;
        for (uint256 i; i < users.length; i++) setUpUser(users[i]);
    }

    function setUpUser(address user) private {
        // give users 1000 ether each and DAI can spend them ;)
        vm.deal(user, 1000 ether);
        deal(DAI, user, 1000 ether);
        deal(USDC, user, 1000 ether);
        vm.startPrank(user);
        IERC20(DAI).approve(address(spleth), type(uint256).max);
        IERC20(USDC).approve(address(spleth), type(uint256).max);
        vm.stopPrank();
    }

    function testCreate() public {
        vm.prank(user1);
        uint256 splitId = spleth.create(users);
        assertEq(spleth.participantsLength(splitId), 2);
        assertEq(spleth.participant(splitId, 0), user1);
        assertEq(spleth.participant(splitId, 1), user2);
    }

    function testInitializeTransaction() public {
        uint256 amount = 14 ether;
        uint256 splitId = 0;
        vm.prank(user1);
        spleth.initializeTransaction(splitId, DAI, amount, receiver);

        assertEq(spleth.token(splitId), DAI, "running token");
        assertEq(spleth.amount(splitId), uint256(amount), "running amount");
        assertEq(spleth.receiver(splitId), receiver, "running receiver");
    }

    function testPartialApproval() public {
        uint256 amount = 1 ether;
        vm.startPrank(user1);
        uint256 splitId = spleth.create(users);
        spleth.initializeTransaction(splitId, DAI, amount, receiver);
        vm.stopPrank();

        vm.prank(user2);
        spleth.approve(splitId);

        assertTrue(spleth.approval(splitId, user2), "has approve");
        assertEq(
            IERC20(DAI).balanceOf(address(spleth)),
            amount / 2,
            "balance spleth"
        );
    }

    function testSend() public {
        uint256 amount = 3 ether + 1;
        vm.startPrank(user1);
        uint256 splitId = spleth.create(users);
        assertEq(spleth.token(splitId), address(0));
        spleth.initializeTransactionAndApprove(splitId, DAI, amount, receiver);
        vm.stopPrank();

        vm.prank(user2);
        spleth.approve(splitId);

        uint256 balanceReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceSpleth = IERC20(DAI).balanceOf(address(spleth));

        assertEq(balanceReceiver, amount, "transferred amount");
        assertEq(balanceSpleth, 2 * amount.divUp(2) - amount, "dust amount");
        // split amount is reset at the end of the function:
        assertEq(spleth.amount(splitId), 0);

        // split properties will be overwritten/reset at the start of a new tx:
        assertEq(spleth.nbApproved(splitId), 2);
        assertEq(spleth.token(splitId), DAI);
        assertEq(spleth.receiver(splitId), receiver);
        //
        vm.prank(user1);
        spleth.initializeTransaction(splitId, USDC, amount / 4, address(1000));
        //
        assertEq(spleth.nbApproved(splitId), 0);
        assertEq(spleth.token(splitId), USDC);
        assertEq(spleth.receiver(splitId), address(1000));
        assertEq(spleth.amount(splitId), amount / 4);
    }
}
