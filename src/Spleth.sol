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
        address runningToken;
        uint256 runningAmount;
        address runningReceiver;
        address[] participants;
        mapping(address => uint256) rankParticipant;
        mapping(address => bool) approval;
        uint256 approved; // number of users who approved
    }

    function create(address[] calldata _participants)
        public
        returns (uint256 splitId)
    {
        splitId = nextId++;
        Split storage split = splits[splitId];
        split.admin = msg.sender;
        split.participants = _participants;
        for (uint256 i; i < _participants.length; i++)
            split.rankParticipant[_participants[i]] = i + 1;
    }

    function initializeTransaction(
        uint256 _splitId,
        address _token,
        uint256 _amount,
        address _receiver
    ) public {
        Split storage split = splits[_splitId];
        require(split.runningAmount == 0);

        split.runningToken = _token;
        split.runningAmount = _amount;
        split.runningReceiver = _receiver;
        for (uint256 i; i < split.participants.length; i++)
            delete split.approval[split.participants[i]];
        delete split.approved;
    }

    function initializeTransactionAndApprove(
        uint256 _splitId,
        address _token,
        uint256 _amount,
        address _receiver
    ) public {
        initializeTransaction(_splitId, _token, _amount, _receiver);
        approve(_splitId);
    }

    function approve(uint256 _splitId) public {
        Split storage split = splits[_splitId];
        require(split.runningAmount != 0);
        require(
            split.rankParticipant[msg.sender] != 0,
            "you should be participating"
        );
        require(split.approval[msg.sender] == false, "you already approved");

        address sToken = split.runningToken;
        uint256 sAmount = split.runningAmount;
        uint256 shareOfAmount = sAmount.divUp(split.participants.length);

        IERC20(sToken).transferFrom(msg.sender, address(this), shareOfAmount);
        split.approval[msg.sender] = true;
        split.approved += 1;

        if (split.approved == split.participants.length) {
            IERC20(sToken).transfer(split.runningReceiver, sAmount);
            split.runningAmount = 0;
        }
    }

    function participant(uint256 _splitId, uint256 _i)
        public
        view
        returns (address)
    {
        return splits[_splitId].participants[_i];
    }

    function participantsLength(uint256 _splitId)
        public
        view
        returns (uint256)
    {
        return splits[_splitId].participants.length;
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

    function approval(uint256 _splitId, address _user)
        public
        view
        returns (bool)
    {
        return splits[_splitId].approval[_user];
    }

    function nbApproved(uint256 _splitId) public view returns (uint256) {
        return splits[_splitId].approved;
    }
}
