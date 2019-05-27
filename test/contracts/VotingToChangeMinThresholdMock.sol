pragma solidity ^0.4.24;

import "../../contracts/VotingToChangeMinThreshold.sol";

contract VotingToChangeMinThresholdMock is VotingToChangeMinThreshold {
  function setMinPossibleThresholdMock(uint256 _value) public {
    uintStorage[keccak256(abi.encodePacked("minPossibleThreshold"))] = _value;
  }

  function setTime(uint256 _newTime) public {
    uintStorage[keccak256(abi.encodePacked("mockTime"))] = _newTime;
  }

  function getTime() public view returns(uint256) {
    uint256 time = uintStorage[keccak256(abi.encodePacked("mockTime"))];
    if (time == 0) {
      return now;
    } else {
      return time;
    }
  }
}
