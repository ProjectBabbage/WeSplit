// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Arith.sol";
import "./WeSplitStructure.sol";

contract WeSplit is UUPSUpgradeable, WeSplitStructure {
    using Arith for uint256;

    function _authorizeUpgrade(address) internal override(UUPSUpgradeable) onlyOwner {}

    function create(address[] calldata _participants) public returns (uint256 id) {
        id = nextId++;
        Split storage split = splits[id];
        split.participants = _participants;
        split.weights = new uint256[](_participants.length);
        for (uint256 i; i < _participants.length; i++)
            split.rankParticipant[_participants[i]] = i + 1;

        emit Created(id, _participants);
    }

    function initialize(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver,
        uint256[] calldata _weights
    ) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating to initialize");
        require(split.amount == 0, "cannot initialize when tx is running");
        require(_amount != 0, "cannot initiliaze a tx of 0 amount");

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
        require(split.amount != 0, "tx has not been initialized yet");
        require(split.rankParticipant[msg.sender] != 0, "you should be participating");
        require(split.approval[msg.sender] == false, "you already approved");

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
        require(split.rankParticipant[_user] != 0, "user should be participating");
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
