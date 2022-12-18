// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/Spleth.sol";

contract TestSpleth is Test {
    Spleth public spleth;
    address user1 = address(123);
    address user2 = address(978);
    address tokenA = address(555);
    address receiver = address(444);

    function setUp() public {
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        spleth = new Spleth(users);
    }

    function testApproval() public {
        vm.prank(user1);
        spleth.initializeGroupPay(tokenA, 1 ether, receiver);

        vm.prank(user2);
        spleth.approveGroupPay();
        
        assertTrue(spleth.approvals(user2), "has approve");
        assertEq(spleth.runningReceiver(), receiver, "running receiver");
        assertEq(spleth.runningAmount(), uint256(1 ether / 2), "running amount");
    }
}
