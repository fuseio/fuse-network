pragma solidity ^0.4.24;

import "../Voting.sol";

contract VotingMock is Voting {

  function setNextBallotIdMock(uint256 _id) public {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }

  function setAcceptedMock(uint256 _id, uint256 _value) public {
    _setAccepted(_id, _value);
  }

  function setBalotStartBlockMock(uint256 _balotId, uint256 block) public {
    uintStorage[keccak256(abi.encodePacked("votingState", _balotId, "startBlock"))] = block;
  }
  function setBalotEndBlockMock(uint256 _balotId, uint256 block) public {
    uintStorage[keccak256(abi.encodePacked("votingState", _balotId, "endBlock"))] = block;
  }
}
