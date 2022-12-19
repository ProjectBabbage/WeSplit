// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

import "../src/Spleth.sol";
import "../src/Arith.sol";

contract TestArith is Test {
    using Arith for uint256;

    function testFailDivZero() public pure {
        uint256 x = 2.4 ether + 1;
        x.divUp(0);
    }

    function testDivision() public {
        uint256 x = 14;
        assertEq(x.divUp(2), 7);
        assertEq(x.divUp(3), 5);
    }

}
