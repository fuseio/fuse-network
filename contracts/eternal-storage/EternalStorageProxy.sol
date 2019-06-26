pragma solidity ^0.4.24;

import "./EternalStorage.sol";

/**
 * @title EternalStorageProxy
 * @dev This proxy holds the storage of the token contract and delegates every call to the current implementation set.
 * Besides, it allows to upgrade the token's behaviour towards further implementations, and provides authorization control functionalities
 */
contract EternalStorageProxy is EternalStorage {
    /**
    * @dev This event will be emitted every time the implementation gets upgraded
    * @param version representing the version number of the upgraded implementation
    * @param implementation representing the address of the upgraded implementation
    */
    event Upgraded(uint256 version, address indexed implementation);

    /**
    * @dev This event will be emitted when ownership is renounces
    * @param previousOwner address which is renounced from ownership
    */
    event OwnershipRenounced(address indexed previousOwner);

    /**
    * @dev This event will be emitted when ownership is transferred
    * @param previousOwner address which represents the previous owner
    * @param newOwner address which represents the new owner
    */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev This modifier verifies that msg.sender is the ProxyStorage contract
    */
    modifier onlyProxyStorage() {
      require(msg.sender == getProxyStorage());
      _;
    }

    /**
    * @dev This modifier verifies that msg.sender is the owner of the contract
    */
    modifier onlyOwner() {
      require(msg.sender == getOwner());
      _;
    }

    /**
    * @dev Constructor
    * @param _proxyStorage address representing the ProxyStorage contract
    * @param _implementation address representing the implementation contract
    */
    constructor(address _proxyStorage, address _implementation) public {
      require(_implementation != address(0));
      if (_proxyStorage != address(0)) {
        _setProxyStorage(_proxyStorage);
      } else {
        _setProxyStorage(address(this));
      }
      _setImplementation(_implementation);
      _setOwner(msg.sender);
    }

    /**
    * @dev Fallback function allowing to perform a delegatecall to the given implementation.
    * This function will return whatever the implementation call returns
    */
    // solhint-disable no-complex-fallback, no-inline-assembly
    function() payable public {
      address _impl = getImplementation();
      require(_impl != address(0));

      assembly {
        // Copy msg.data. We take full control of memory in this inline assembly
        // block because it will not return to Solidity code. We overwrite the
        // Solidity scratch pad at memory position 0
        calldatacopy(0, 0, calldatasize)

        // Call the implementation.
        // out and outsize are 0 because we don't know the size yet
        let result := delegatecall(gas, _impl, 0, calldatasize, 0, 0)

        // Copy the returned data
        returndatacopy(0, 0, returndatasize)

        switch result
        // delegatecall returns 0 on error
        case 0 { revert(0, returndatasize) }
        default { return(0, returndatasize) }
      }
    }
    // solhint-enable no-complex-fallback, no-inline-assembly

    /**
     * @dev Allows ProxyStorage contract (only) to upgrade the current implementation.
     * @param _newImplementation representing the address of the new implementation to be set.
     */
    function upgradeTo(address _newImplementation) public onlyProxyStorage returns(bool) {
      if (_newImplementation == address(0)) return false;
      if (getImplementation() == _newImplementation) return false;
      uint256 _newVersion = getVersion() + 1;
      _setVersion(_newVersion);
      _setImplementation(_newImplementation);
      emit Upgraded(_newVersion, _newImplementation);
      return true;
    }

    /**
     * @dev Allows the current owner to relinquish ownership.
     */
    function renounceOwnership() public onlyOwner {
      emit OwnershipRenounced(getOwner());
      _setOwner(address(0));
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a _newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
      require(_newOwner != address(0));
      emit OwnershipTransferred(getOwner(), _newOwner);
      _setOwner(_newOwner);
    }

    function getOwner() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("owner"))];
    }

    function _setOwner(address _owner) private {
      addressStorage[keccak256(abi.encodePacked("owner"))] = _owner;
    }

    function getVersion() public view returns(uint256) {
      return version;
    }

    function _setVersion(uint256 _newVersion) private {
      version = _newVersion;
    }

    function getImplementation() public view returns(address) {
      return implementation;
    }

    function _setImplementation(address _newImplementation) private {
      implementation = _newImplementation;
    }

    function getProxyStorage() public view returns(address) {
      return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
    }

    function _setProxyStorage(address _proxyStorage) private {
      addressStorage[keccak256(abi.encodePacked("proxyStorage"))] = _proxyStorage;
    }
}
