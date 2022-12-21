// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Spleth.sol";

contract DeploySpleth is Script {
    function run() public {
        address[] memory participants = new address[](2);
        participants[0] = 0x6D0aCddE929e5e1f33DC11BDE288af36F5423Bde;
        participants[1] = 0xAB0390Fd2eD82a683e2D65F501D7c5b5E42a9F1e;
        vm.broadcast();
        new Spleth(participants);
    }
}
