// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/OwnableProxy.sol";
import "../src/WeSplit.sol";

contract DeployWeSplit is Script {
    bytes public constant emptyData = "";

    function run() public {
        vm.startBroadcast();
        WeSplit weSplitImplementation = new WeSplit();
        new OwnableProxy(address(weSplitImplementation), emptyData);
        vm.stopBroadcast();
    }
}
