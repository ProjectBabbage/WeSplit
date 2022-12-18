// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../src/Spleth.sol";

contract TestArith is Test {

    function divUp(uint256 x, uint256 y) private pure returns (uint256) {
        return (x + y - 1) / y;
    }

    function testFailDivZero() public pure {
        uint256 x = 2.4 ether + 1;
        divUp(x, 0);
    }

    function testDivision() public {
        uint256 x = 14;
        assertEq(divUp(x, 2), 7);
        assertEq(divUp(x, 3), 5);
    }

}
