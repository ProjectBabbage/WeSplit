// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Spleth.sol";

contract TestSpleth is Test {
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
        vm.prank(user1);
        spleth.initializeGroupPay(DAI, 1 ether, receiver);

        vm.prank(user2);
        spleth.approveGroupPay();

        assertTrue(spleth.approvals(user2), "has approve");
        assertEq(spleth.runningReceiver(), receiver, "running receiver");
        assertEq(spleth.runningAmount(), uint256(1 ether / 2), "running amount");
        assertEq(IERC20(DAI).balanceOf(address(spleth)), 1 ether / 2);
    }
}
