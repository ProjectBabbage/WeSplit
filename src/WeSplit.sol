// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "./Arith.sol";

contract WeSplit {
    using Arith for uint256;

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

    uint256 public nextId;
    mapping(uint256 => Split) splits;

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

    function create(address[] calldata _participants) public returns (uint256 id) {
        id = nextId++;
        Split storage split = splits[id];
        split.participants = _participants;
        split.weights = new uint256[](_participants.length);
        for (uint256 i; i < _participants.length; i++)
            split.rankParticipant[_participants[i]] = i + 1;

        emit Created(id, _participants);
    }

    function addParticipant(uint256 _id, address _participant) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount == 0, "tx is running");

        address[] storage sParticipants = split.participants;

        sParticipants.push(_participant);
        split.rankParticipant[_participant] = sParticipants.length;
    }

    function removeParticipant(uint256 _id, address _participant) public {
        Split storage split = splits[_id];
        uint256 participantRank = split.rankParticipant[_participant];
        require(participantRank != 0, "must be participating");
        require(split.amount == 0, "tx is running");

        address[] storage sParticipants = split.participants;
        uint256 length = sParticipants.length;
        require(length != 1, "cannot remove last participant");

        address lastParticipant = sParticipants[length - 1];
        sParticipants[participantRank - 1] = lastParticipant;
        sParticipants.pop();
        split.rankParticipant[_participant] = 0;
        split.rankParticipant[lastParticipant] = participantRank;
    }

    function initialize(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver,
        uint256[] calldata _weights
    ) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount == 0, "tx is running");
        require(_amount != 0, "amount is 0");

        if (_weights.length == 0) {
            // if no correct weights are provided, it defaults to an array of ones
            for (uint256 i; i < split.participants.length; i++) split.weights[i] = 1;
        } else {
            require(
                _weights.length == split.participants.length,
                "weights sould have the same size as participants"
            );
            split.weights = _weights;
        }

        address[] memory sParticipants = split.participants;
        split.token = _token;
        split.amount = _amount;
        split.receiver = _receiver;
        for (uint256 i; i < sParticipants.length; i++) delete split.approval[sParticipants[i]];
        delete split.approvalCount;

        emit Initialized(_id, sParticipants, _token, _amount, _receiver);
    }

    function approve(uint256 _id) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount != 0, "tx is not running");
        require(split.approval[msg.sender] == false, "already approved");

        address[] memory sParticipants = split.participants;
        address sToken = split.token;
        uint256 sAmount = split.amount;

        split.approval[msg.sender] = true;
        split.approvalCount += 1;

        if (split.approvalCount == sParticipants.length) {
            uint256 weightsSum;
            for (uint256 i; i < sParticipants.length; i++) weightsSum += split.weights[i];
            for (uint256 i; i < sParticipants.length; i++) {
                uint256 shareOfAmount = (sAmount * split.weights[i]).divUp(weightsSum);
                IERC20(sToken).transferFrom(sParticipants[i], address(this), shareOfAmount);
            }
            IERC20(sToken).transfer(split.receiver, sAmount);
            split.amount = 0;
        }

        emit Approved(_id, sParticipants, msg.sender, sAmount);
    }

    function initializeApprove(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver,
        uint256[] calldata _weights
    ) public {
        initialize(_id, _token, _amount, _receiver, _weights);
        approve(_id);
    }

    function createInitializeApprove(
        address[] calldata _participants,
        address _token,
        uint256 _amount,
        address _receiver,
        uint256[] calldata _weights
    ) public returns (uint256 id) {
        id = create(_participants);
        initializeApprove(id, _token, _amount, _receiver, _weights);
    }

    function participants(uint256 _id) public view returns (address[] memory) {
        return splits[_id].participants;
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

    function token(uint256 _id) public view returns (address) {
        return splits[_id].token;
    }

    function amount(uint256 _id) public view returns (uint256) {
        return splits[_id].amount;
    }

    function receiver(uint256 _id) public view returns (address) {
        return splits[_id].receiver;
    }

    function weights(uint256 _id) public view returns (uint256[] memory) {
        return splits[_id].weights;
    }

    function checkTransferabilityUser(uint256 _id, address _user) public view returns (bool) {
        Split storage split = splits[_id];
        if (split.rankParticipant[_user] == 0) return false;
        mapping(address => bool) storage sApproval = split.approval;
        address[] memory sParticipants = split.participants;
        address sToken = split.token;
        uint256 sAmount = split.amount;
        uint256 length = sParticipants.length;
        uint256 shareOfAmount = sAmount.divUp(length);

        bool enoughAllowed = IERC20(sToken).allowance(_user, address(this)) > shareOfAmount;
        bool enoughBalance = IERC20(sToken).balanceOf(_user) > shareOfAmount;
        bool approved = sApproval[_user];
        return enoughAllowed && enoughBalance && approved;
    }

    function checkTransferability(uint256 _id) public view returns (bool) {
        Split storage split = splits[_id];
        address[] memory sParticipants = split.participants;
        for (uint256 i; i < sParticipants.length; i++)
            if (!checkTransferabilityUser(_id, sParticipants[i])) return false;
        return true;
    }
}
