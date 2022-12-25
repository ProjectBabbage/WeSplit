// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Spleth.sol";

contract DeploySpleth is Script {
    function run() public {
        vm.broadcast();
        new Spleth();
    }
}
