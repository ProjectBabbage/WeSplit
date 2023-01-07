// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/WeSplit.sol";

contract UpgradeWeSplit is Script {
    address constant internal weSplitProxy = 0x52decE2Fd883628eA46eBae183cd9D78a81Ef916;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        WeSplit newWeSplitImplementation = new WeSplit();
        WeSplit(weSplitProxy).upgradeTo(address(newWeSplitImplementation));
        vm.stopBroadcast();
    }
}
