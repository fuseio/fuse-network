pragma solidity ^0.4.24;

import "../../contracts/Voting.sol";

contract VotingMock is Voting {
  function setMinBallotDurationCyclesMock(uint256 _value) public {
    uintStorage[keccak256(abi.encodePacked("minBallotDurationCycles"))] = _value;
  }
}
