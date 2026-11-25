
pragma solidity ^0.8.0;

import '../eternal-storage/EternalStorageProxy.sol';

contract EternalStorageProxyMock is EternalStorageProxy {
  constructor(address _proxyStorage, address _implementation) EternalStorageProxy(_proxyStorage, _implementation) {}

  function setProxyStorageMock(address _proxyStorage) public {
    addressStorage[keccak256(abi.encodePacked("proxyStorage"))] = _proxyStorage;
  }
}
