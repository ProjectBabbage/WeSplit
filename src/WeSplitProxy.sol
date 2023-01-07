// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./WeSplitStructure.sol";

/// @title WeSplit Proxy contract.
/// @author Project Babbage.
contract WeSplitProxy is ERC1967Proxy, WeSplitStructure {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) Ownable() {}
}
