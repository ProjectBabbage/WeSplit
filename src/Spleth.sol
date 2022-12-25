// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./Arith.sol";

contract Spleth {
    using Arith for uint256;

    uint256 public nextId;
    mapping(uint256 => Split) splits;

    struct Split {
        address admin;
        bool running;
        address runningToken;
        uint256 runningAmount;
        address runningReceiver;
        address[] participants;
        mapping(address => uint256) rankParticipant;
        mapping(address => bool) approval;
        uint256 approved; // number of users who approved
    }

    function create(address _token, uint256 _amount, address _receiver, address[] calldata participants) public returns (uint256 splitId) {
        splitId = nextId++;
        Split storage split = splits[splitId];


        split.admin = msg.sender;
        split.running = true;
        split.runningToken = _token;
        split.runningAmount = _amount;
        split.runningReceiver = _receiver;
        split.participants = participants;
        for (uint256 i; i < participants.length; i++)
            split.rankParticipant[participants[i]] = i+1;
    }

    function createAndApprove(address _token, uint256 _amount, address _receiver, address[] calldata participants) public returns (uint256 splitId) {
        splitId = create(_token, _amount, _receiver, participants);
        approve(splitId);
    }

    function approve(uint256 _splitId) public {
        Split storage split = splits[_splitId];
        require (split.running);
        require (split.rankParticipant[msg.sender] != 0, "you should be participating");
        require (split.approval[msg.sender] == false, "you already approved");

        address sToken = split.runningToken;
        uint256 sAmount = split.runningAmount;
        uint256 shareOfAmount = sAmount.divUp(split.participants.length);

        IERC20(sToken).transferFrom(msg.sender, address(this), shareOfAmount);
        split.approval[msg.sender] = true;
        split.approved += 1;

        if (split.approved == split.participants.length) IERC20(sToken).transfer(split.runningReceiver, sAmount);
    }

    function running(uint256 _splitId) public view returns (bool) {
        return splits[_splitId].running;
    }

    function token(uint256 _splitId) public view returns (address) {
        return splits[_splitId].runningToken;
    }

    function amount(uint256 _splitId) public view returns (uint256) {
        return splits[_splitId].runningAmount;
    }

    function receiver(uint256 _splitId) public view returns (address) {
        return splits[_splitId].runningReceiver;
    }

    function approval(uint256 _splitId, address _user) public view returns (bool) {
        return splits[_splitId].approval[_user];
    } 

}
