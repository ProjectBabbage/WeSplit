// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./Arith.sol";

contract WeSplit {
    using Arith for uint256;

    uint256 public nextId;
    mapping(uint256 => Split) splits;

    struct Split {
        address token;
        uint256 amount;
        address receiver;
        address[] participants;
        mapping(address => uint256) rankParticipant;
        mapping(address => bool) approval;
        uint256 approvalCount; // number of users who approved
    }

    function create(address[] calldata _participants) public returns (uint256 id) {
        id = nextId++;
        Split storage split = splits[id];
        split.participants = _participants;
        for (uint256 i; i < _participants.length; i++)
            split.rankParticipant[_participants[i]] = i + 1;
    }

    function initialize(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver
    ) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating to initialize");
        require(split.amount == 0, "cannot initialize when tx is running");
        require(_amount != 0, "cannot initiliaze a tx of 0 amount");

        split.token = _token;
        split.amount = _amount;
        split.receiver = _receiver;
        for (uint256 i; i < split.participants.length; i++)
            delete split.approval[split.participants[i]];
        delete split.approvalCount;
    }

    function approve(uint256 _id) public {
        Split storage split = splits[_id];
        require(split.amount != 0, "tx has not been initialized yet");
        require(split.rankParticipant[msg.sender] != 0, "you should be participating");
        require(split.approval[msg.sender] == false, "you already approved");

        address sToken = split.token;
        uint256 sAmount = split.amount;
        uint256 shareOfAmount = sAmount.divUp(split.participants.length);

        IERC20(sToken).transferFrom(msg.sender, address(this), shareOfAmount);
        split.approval[msg.sender] = true;
        split.approvalCount += 1;

        if (split.approvalCount == split.participants.length) {
            IERC20(sToken).transfer(split.receiver, sAmount);
            split.amount = 0;
        }
    }

    function initializeApprove(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver
    ) public {
        initialize(_id, _token, _amount, _receiver);
        approve(_id);
    }

    function createInitializeApprove(
        address[] calldata _participants,
        address _token,
        uint256 _amount,
        address _receiver
    ) public returns (uint256 id) {
        id = create(_participants);
        initializeApprove(id, _token, _amount, _receiver);
    }

    function participantsLength(uint256 _id) public view returns (uint256) {
        return splits[_id].participants.length;
    }

    function token(uint256 _id) public view returns (address) {
        return splits[_id].token;
    }

    function amount(uint256 _id) public view returns (uint256) {
        return splits[_id].amount;
    }

    function receiver(uint256 _id) public view returns (address) {
        return splits[_id].receiver;
    }

    function participant(uint256 _id, uint256 _index) public view returns (address) {
        return splits[_id].participants[_index];
    }

    function rankParticipant(uint256 _id, address _user) public view returns (uint256) {
        return splits[_id].rankParticipant[_user];
    }

    function approval(uint256 _id, address _user) public view returns (bool) {
        return splits[_id].approval[_user];
    }

    function approvalCount(uint256 _id) public view returns (uint256) {
        return splits[_id].approvalCount;
    }
}
