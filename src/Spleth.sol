// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "forge-std/console.sol";

contract Spleth {

    bool public running;
    uint256 public runningAmount;
    address public runningToken;
    address public runningReceiver;
    address[] public participants;
    mapping(address => bool) public approvals;

    constructor(address[] memory addresses) {
        participants = addresses;
    }

    function initializeGroupPay(address token, uint256 amount, address receiver) public {
        require (!running);
        runningAmount = amount / participants.length;
        runningToken = token;
        runningReceiver = receiver;
    }

    function approveGroupPay() public {
        bool isParticipating;
        for (uint256 i; i < participants.length; i++)
            if (isParticipating = participants[i] == msg.sender) {
                isParticipating = true;
                break;
            } // todo: opptimize this
        require (isParticipating, "user should be participating");
        IERC20(runningToken).transferFrom(msg.sender, address(this), runningAmount);
        approvals[msg.sender] = true;
    }
}
