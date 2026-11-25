
pragma solidity ^0.8.0;

import "../ProxyStorage.sol";

contract ProxyStorageMock is ProxyStorage {
  function setBlockRewardMock(address _newAddress) public {
    addressStorage[BLOCK_REWARD] = _newAddress;
  }

  function setConsensusMock(address _newAddress) public {
    addressStorage[CONSENSUS] = _newAddress;
  }

  function upgradeBlockRewardMock(address _implementation) public {
    EternalStorageProxy(payable(getBlockReward())).upgradeTo(_implementation);
  }

  function upgradeConsensusMock(address _implementation) public {
    EternalStorageProxy(payable(getConsensus())).upgradeTo(_implementation);
  }
}
