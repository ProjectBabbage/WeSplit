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
    address receiver = address(444);
    address[] users = new address[](2);

    function setUp() public {
        spleth = new Spleth();
        users[0] = user1;
        users[1] = user2;
        for (uint i; i < users.length; i++)
            setUpUser(users[i]);
    }

    function setUpUser(address user) private {
        vm.deal(user, 1000 ether);
        deal(DAI, user, 1000 ether);
        vm.prank(user);
        IERC20(DAI).approve(address(spleth), type(uint256).max);
    }

    function testInitialize() public {
        uint256 amount = 14 ether;
        vm.prank(user1);
        uint256 splitId = spleth.create(DAI, amount, receiver, users);

        assertTrue(spleth.running(splitId), "running token");
        assertEq(spleth.token(splitId), DAI, "running token");
        assertEq(spleth.amount(splitId), uint256(amount), "running amount");
        assertEq(spleth.receiver(splitId), receiver, "running receiver");
    }

    function testApproval() public {
        uint256 amount = 1 ether;
        vm.prank(user1);
        uint256 splitId = spleth.create(DAI, amount, receiver, users);

        vm.prank(user2);
        spleth.approve(splitId);

        assertTrue(spleth.approval(splitId, user2), "has approve");
        assertEq(IERC20(DAI).balanceOf(address(spleth)), amount / 2, "balance spleth");
    }

    function testSend() public {
        uint256 amount = 3 ether + 1;
        vm.prank(user1);
        uint256 splitId = spleth.createAndApprove(DAI, amount, receiver, users);

        vm.prank(user2);
        spleth.approve(splitId);

        uint256 balanceReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceSpleth = IERC20(DAI).balanceOf(address(spleth));

        assertEq(balanceReceiver, amount, "transferred amount");
        assertEq(balanceSpleth, 2 * amount.divUp(2) - amount, "dust amount");
    }
}
