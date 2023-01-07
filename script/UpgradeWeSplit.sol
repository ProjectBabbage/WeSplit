// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "src/WeSplit.sol";

contract UpgradeWeSplit is Script {
    function run(address _weSplitProxy) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        WeSplit newWeSplitImplementation = new WeSplit();
        WeSplit(_weSplitProxy).upgradeTo(address(newWeSplitImplementation));
        vm.stopBroadcast();
    }
}
