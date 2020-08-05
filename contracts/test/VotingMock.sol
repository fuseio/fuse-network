pragma solidity ^0.4.24;

import "../Voting.sol";

contract VotingMock is Voting {

  function setNextBallotIdMock(uint256 _id) public {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }
}
