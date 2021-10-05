pragma solidity ^0.4.24;

import "../Voting.sol";

contract VotingMock is Voting {

  bytes32 internal constant CONSESNSUS_MOCK = keccak256(abi.encodePacked("consensusMock"));
 
  function setNextBallotIdMock(uint256 _id) public {
    uintStorage[NEXT_BALLOT_ID] = _id;
  }

  function setConsensusMock(address _consensus) public {
    addressStorage[CONSESNSUS_MOCK] = _consensus;
  }

  /**
  * @dev This modifier verifies that msg.sender is the consensus contract
  */
  modifier onlyConsensus() {
    if (addressStorage[CONSESNSUS_MOCK] != address(0)) {
      require(msg.sender == addressStorage[CONSESNSUS_MOCK]);
    } else {
      require(msg.sender == ProxyStorage(getProxyStorage()).getConsensus());
    }
    _;
  }
}
