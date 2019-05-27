pragma solidity ^0.4.24;

import "../../contracts/VotingToChangeBlockReward.sol";

contract VotingToChangeBlockRewardMock is VotingToChangeBlockReward {
  function setMinPossibleBlockRewardMock(uint256 _value) public {
    uintStorage[keccak256(abi.encodePacked("minPossibleBlockReward"))] = _value;
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
