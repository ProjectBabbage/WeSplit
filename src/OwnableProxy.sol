// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OwnableProxy is ERC1967Proxy, Ownable {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) Ownable() {}
}
