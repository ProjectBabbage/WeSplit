// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract Spleth {

    bool public running;
    address public runningToken;
    uint256 public runningAmount;
    address public runningReceiver;
    address[] public participants;
    mapping(address => bool) public approvals;
    uint256 approved; // number of users who approved

    constructor(address[] memory addresses) {
        participants = addresses;
    }

    function divUp(uint256 x, uint256 y) private pure returns (uint256) {
        return (x + y - 1) / y;
    }

    function initializeGroupPayWithoutApprove(address token, uint256 amount, address receiver) public {
        require (!running);

        running = true;
        runningToken = token;
        runningAmount = amount;
        runningReceiver = receiver;
    }

    function initializeGroupPay(address token, uint256 amount, address receiver) public {
        initializeGroupPayWithoutApprove(token, amount, receiver);
        approveGroupPay();
    }

    function approveGroupPay() public {
        require (running);
        bool isParticipating;
        for (uint256 i; i < participants.length; i++)
            if (isParticipating = participants[i] == msg.sender) {
                isParticipating = true;
                break;
            } // todo: optimize this
        require (isParticipating, "you should be participating");
        require (approvals[msg.sender] == false, "you already approved");

        uint amount = runningAmount;
        uint256 shareOfAmount = divUp(amount, participants.length);

        IERC20(runningToken).transferFrom(msg.sender, address(this), shareOfAmount);
        approvals[msg.sender] = true;
        approved += 1;

        if (approved == participants.length) IERC20(runningToken).transfer(runningReceiver, amount);
    }

}
