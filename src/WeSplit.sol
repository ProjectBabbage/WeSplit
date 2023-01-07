// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Arith.sol";
import "./WeSplitStructure.sol";

/// @title WeSplit Implementation contract.
/// @author Project Babbage.
contract WeSplit is UUPSUpgradeable, WeSplitStructure {
    using Arith for uint256;

    function _authorizeUpgrade(address) internal override(UUPSUpgradeable) onlyOwner {}

    /// @notice Creates a new split and returns the corresponding id.
    /// @param _participants the initial participants of the split to create.
    /// @return id the id of the split created.
    function create(address[] calldata _participants) public returns (uint256 id) {
        id = nextId++;
        Split storage split = splits[id];
        split.participants = _participants;
        split.weights = new uint256[](_participants.length);
        for (uint256 i; i < _participants.length; i++)
            split.rankParticipant[_participants[i]] = i + 1;

        emit Created(id, _participants);
    }

    /// @notice Add a participant to a non-active split.
    /// @param _id the id of the split in which to add a participant.
    /// @param _participant the participant to add.
    function addParticipant(uint256 _id, address _participant) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount == 0, "tx is initialized");

        address[] storage sParticipants = split.participants;

        sParticipants.push(_participant);
        split.rankParticipant[_participant] = sParticipants.length;
    }

    /// @notice Remove a participant to a non-active split.
    /// @param _id the id of the split in which to remove a participant.
    /// @param _participant the participant to remove.
    function removeParticipant(uint256 _id, address _participant) public {
        Split storage split = splits[_id];
        uint256 participantRank = split.rankParticipant[_participant];
        require(participantRank != 0, "must be participating");
        require(split.amount == 0, "tx is initialized");

        address[] storage sParticipants = split.participants;
        uint256 length = sParticipants.length;
        require(length != 1, "cannot remove last participant");

        address lastParticipant = sParticipants[length - 1];
        sParticipants[participantRank - 1] = lastParticipant;
        sParticipants.pop();
        split.rankParticipant[_participant] = 0;
        split.rankParticipant[lastParticipant] = participantRank;
    }

    /// @notice Initialize a transaction in a split.
    /// @param _id the id of the split in which to initialize a transaction.
    /// @param _token the token to send.
    /// @param _amount the amount of token to send.
    /// @param _receiver the user that will receive the tokens.
    /// @param _weights the weights determining the participation.
    function initialize(
        uint256 _id,
        address _token,
        uint256 _amount,
        address _receiver,
        uint256[] calldata _weights
    ) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount == 0, "tx is initialized");
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

    /// @notice Approve the transaction that has been initialized.
    /// @param _id the id of the corresponding split.
    function approve(uint256 _id) public {
        Split storage split = splits[_id];
        require(split.rankParticipant[msg.sender] != 0, "must be participating");
        require(split.amount != 0, "tx is not initialized");
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


    /// @notice Initialize a transaction and approve it.
    /// @param _id the id of the split in which to initialize and approve a transaction.
    /// @param _token the token to send.
    /// @param _amount the amount of token to send.
    /// @param _receiver the user that will receive the tokens.
    /// @param _weights the weights determining the participation.
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

    /// @notice Create a new split, initialize a transaction in this split and approve it.
    /// @param _participants the initial participants of the split to create.
    /// @param _token the token to send.
    /// @param _amount the amount of token to send.
    /// @param _receiver the user that will receive the tokens.
    /// @param _weights the weights determining the participation.
    /// @return id the id of the split created.
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

    /// @notice Return the participants of a split.
    /// @param _id the id of the split to look for.
    function participants(uint256 _id) public view returns (address[] memory) {
        return splits[_id].participants;
    }

    /// @notice Return the ranks of the participants in a split.
    /// @param _id the id of the split to look for.
    function rankParticipant(uint256 _id, address _user) public view returns (uint256) {
        return splits[_id].rankParticipant[_user];
    }

    /// @notice Check if a user is approving a transation.
    /// @param _id the id of the split to look for.
    /// @param _user the user the check.
    function approval(uint256 _id, address _user) public view returns (bool) {
        return splits[_id].approval[_user];
    }

    /// @notice Return the number of users approving the transaction in a split.
    /// @param _id the id of the split to look for.
    function approvalCount(uint256 _id) public view returns (uint256) {
        return splits[_id].approvalCount;
    }

    /// @notice Return the token of the transaction in a split.
    /// @param _id the id of the split to look for.
    function token(uint256 _id) public view returns (address) {
        return splits[_id].token;
    }

    /// @notice Return the amount of token of the transaction in a split.
    /// @param _id the id of the split to look for.
    function amount(uint256 _id) public view returns (uint256) {
        return splits[_id].amount;
    }

    /// @notice Return the receiver of the transaction in a split.
    /// @param _id the id of the split to look for.
    function receiver(uint256 _id) public view returns (address) {
        return splits[_id].receiver;
    }

    /// @notice Return the weights of the transaction in a split.
    /// @param _id the id of the split to look for.
    function weights(uint256 _id) public view returns (uint256[] memory) {
        return splits[_id].weights;
    }

    /// @notice Return the transferability of a user in a split.
    /// @dev Checks whether the user has a sufficient balance, has a sufficient allowance, and has approved the transaction.
    /// @param _id the id of the split to look for.
    /// @param _user the user to check.
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

    /// @notice Return the transferability of a transaction in a split.
    /// @dev Checks that each user has a sufficient balance, has a sufficient allowance, and has approved the transaction.
    /// @param _id the id of the split to look for.
    function checkTransferability(uint256 _id) public view returns (bool) {
        Split storage split = splits[_id];
        address[] memory sParticipants = split.participants;
        for (uint256 i; i < sParticipants.length; i++)
            if (!checkTransferabilityUser(_id, sParticipants[i])) return false;
        return true;
    }
}
