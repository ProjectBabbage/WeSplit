// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Arith.sol";
import "../src/Spleth.sol";

contract TestSpleth is Test {
    using Arith for uint256;

    Spleth public spleth;
    address user1 = address(123);
    address user2 = address(978);
    address DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address receiver = address(444);

    function setUp() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        spleth = new Spleth(users);
        for (uint i; i < users.length; i++)
            setUpUser(users[i]);
    }

    function setUpUser(address user) private {
        vm.deal(user, 1000 ether);
        deal(DAI, user, 1000 ether);
        vm.prank(user);
        IERC20(DAI).approve(address(spleth), type(uint256).max);
    }

    function testApproval() public {
        uint256 amount = 1 ether;
        vm.prank(user1);
        spleth.initializeGroupPayWithoutApprove(DAI, amount, receiver);

        vm.prank(user2);
        spleth.approveGroupPay();

        assertTrue(spleth.approvals(user2), "has approve");
        assertEq(spleth.runningReceiver(), receiver, "running receiver");
        assertEq(spleth.runningAmount(), uint256(amount), "running amount");
        assertEq(IERC20(DAI).balanceOf(address(spleth)), amount / 2, "balance spleth");
    }

    function testSend() public {
        uint256 amount = 3 ether + 1;
        vm.prank(user1);
        spleth.initializeGroupPay(DAI, amount, receiver);

        vm.prank(user2);
        spleth.approveGroupPay();

        uint256 balanceReceiver = IERC20(DAI).balanceOf(receiver);
        uint256 balanceSpleth = IERC20(DAI).balanceOf(address(spleth));
        assertEq(balanceReceiver, amount, "transferred amount");
        assertEq(balanceSpleth, 2 * amount.divUp(2) - amount, "transferred amount");
    }
}
