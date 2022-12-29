// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/access/Ownable.sol";

contract WeSplitStructure is Ownable {
    uint256 public nextId;
    mapping(uint256 => Split) internal splits;

    struct Split {
        address[] participants; // the array of all participants in the split
        mapping(address => uint256) rankParticipant; // the rank of the participant in the participants array (the first participant rank is 1, not 0)
        mapping(address => bool) approval; // to know if a participant has approved
        uint256 approvalCount; // number of users who approved the current tx
        address token; // the token for the current tx
        uint256 amount; // the total amount for the current tx
        address receiver; // the receiver for the current tx
        uint256[] weights; // the weights for the current tx
    }

    event Created(uint256 indexed id, address[] participants);

    event Initialized(
        uint256 indexed id,
        address[] participants,
        address token,
        uint256 amount,
        address indexed receiver
    );

    event Approved(
        uint256 indexed id,
        address[] participants,
        address indexed approver,
        uint256 amount
    );
}
