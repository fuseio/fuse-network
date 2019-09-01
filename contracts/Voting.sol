pragma solidity ^0.4.24;

import "./VotingUtils.sol";

/**
* @title Contract handling vote to change implementations network contracts
* @author LiorRabin
*/
contract Voting is VotingUtils {
  /**
  * @dev Function to be called on contract initialization
  */
  function initialize() external onlyOwner {
    require(!isInitialized());
    setInitialized(true);
  }

  /**
  * @dev Function to create a new ballot
  * @param _startAfterNumberOfCycles number of cycles after which the ballot should open for voting
  * @param _cyclesDuration number of cycles the ballot will remain open for voting
  * @param _contractType contract type to change its address (See ProxyStorage.ContractTypes)
  * @param _proposedValue proposed address for the contract type
  * @param _description ballot text description
  */
  function newBallot(uint256 _startAfterNumberOfCycles, uint256 _cyclesDuration, uint256 _contractType, address _proposedValue, string _description) external onlyValidVotingKey(msg.sender) onlyValidDuration(_startAfterNumberOfCycles, _cyclesDuration) returns(uint256) {
    require(_proposedValue != address(0));
    require(validContractType(_contractType));
    uint256 ballotId = _createBallot(_startAfterNumberOfCycles, _cyclesDuration, _description);
    _setProposedValue(ballotId, _proposedValue);
    _setContractType(ballotId, _contractType);
    return ballotId;
  }

  /**
  * @dev Function to get specific ballot info along with voters involvment on it
  * @param _id ballot id to get info of
  * @param _key voter key to get if voted already
  */
  function getBallotInfo(uint256 _id, address _key) external view returns(uint256 startBlock, uint256 endBlock, bool isFinalized, address proposedValue, uint256 contractType, address creator, string description, bool canBeFinalizedNow, bool alreadyVoted) {
    startBlock = getStartBlock(_id);
    endBlock = getEndBlock(_id);
    isFinalized = getIsFinalized(_id);
    proposedValue = getProposedValue(_id);
    contractType = getContractType(_id);
    creator = getCreator(_id);
    description = getDescription(_id);
    canBeFinalizedNow = canBeFinalized(_id);
    alreadyVoted = hasAlreadyVoted(_id, _key);

    return (startBlock, endBlock, isFinalized, proposedValue, contractType, creator, description, canBeFinalizedNow, alreadyVoted);
  }

  /**
  * @dev This function is used to vote on a ballot
  * @param _id ballot id to vote on
  * @param _choice voting decision on the ballot (see VotingBase.ActionChoices)
  */
  function vote(uint256 _id, uint256 _choice) external {
    require(!getIsFinalized(_id));
    address voter = msg.sender;
    require(isActiveBallot(_id));
    require(!hasAlreadyVoted(_id, voter));
    require(_choice == uint(ActionChoices.Accept) || _choice == uint(ActionChoices.Reject));
    _setVoterChoice(_id, voter, _choice);
    emit Vote(_id, _choice, voter);
  }

  /**
  * @dev Function to be called by the consensus contract when a cycles ends
  * In this function, all active ballots votes will be counted and updated according to the current validators
  */
  function onCycleEnd(address[] validators) external onlyConsensus {
    uint256 numOfValidators = validators.length;
    if (numOfValidators == 0) {
      return;
    }
    uint[] memory ballots = activeBallots();
    for (uint256 i = 0; i < ballots.length; i++) {
      uint256 ballotId = ballots[i];
      if (getStartBlock(ballotId) < block.number && !getFinalizeCalled(ballotId)) {
        uint256 accepts = 0;
        uint256 rejects = 0;
        for (uint256 j = 0; j < numOfValidators; j++) {
          uint256 choice = getVoterChoice(ballotId, validators[j]);
          if (choice == uint(ActionChoices.Accept)) {
            accepts = accepts.add(1);
          } else if (choice == uint256(ActionChoices.Reject)) {
            rejects = rejects.add(1);
          }
        }
        accepts = accepts.mul(DECIMALS).div(numOfValidators);
        rejects = rejects.mul(DECIMALS).div(numOfValidators);
        _setAccepted(ballotId, getAccepted(ballotId).add(accepts));
        _setRejected(ballotId, getRejected(ballotId).add(rejects));

        if (canBeFinalized(ballotId)) {
          _finalize(ballotId);
        }
      }
    }
  }
}
