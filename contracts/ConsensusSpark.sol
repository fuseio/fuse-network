pragma solidity ^0.8.0;

import "./Consensus.sol";

/**
* @title Consensus for the Spark testnet
* @dev Identical to Consensus except for the cycle length: Spark runs 1 hour cycles (720 blocks of 5 seconds)
* instead of 48 hours, so ballots, jailing and cycle rewards can be tested in hours rather than days.
* Deploy this contract, not Consensus, when upgrading Spark's Consensus, or Spark's cycles go back to 48 hours.
* Note that the inherited CYCLE_DURATION_BLOCKS constant still reads the mainnet value; getCycleDurationBlocks()
* is what the contracts use.
*/
contract ConsensusSpark is Consensus {
  uint256 public constant SPARK_CYCLE_DURATION_BLOCKS = 720; // 1 hour [60*60/5]

  function getCycleDurationBlocks() public pure virtual override returns(uint256) {
    return SPARK_CYCLE_DURATION_BLOCKS;
  }
}
