// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/WeSplitProxy.sol";
import "../src/WeSplit.sol";

contract DeployWeSplit is Script {
    bytes public constant emptyData = "";

    function run() public {
        vm.startBroadcast();
        WeSplit weSplitImplementation = new WeSplit();
        new WeSplitProxy(address(weSplitImplementation), emptyData);
        vm.stopBroadcast();
    }
}
