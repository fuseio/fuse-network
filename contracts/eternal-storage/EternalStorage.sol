pragma solidity ^0.4.24;


/**
 * @title EternalStorage
 * @author LiorRabin
 * @dev This contract holds all the necessary state variables to carry out the storage of any contract and to support the upgrade functionality.
 */
contract EternalStorage {
    // Version number of the current implementation
    uint256 internal version;

    // Address of the current implementation
    address internal implementation;

    // Storage mappings
    mapping(bytes32 => uint256) internal uintStorage;
    mapping(bytes32 => string) internal stringStorage;
    mapping(bytes32 => address) internal addressStorage;
    mapping(bytes32 => bytes) internal bytesStorage;
    mapping(bytes32 => bool) internal boolStorage;
    mapping(bytes32 => int256) internal intStorage;
    mapping(bytes32 => bytes32) internal bytes32Storage;

    mapping(bytes32 => uint256[]) internal uintArrayStorage;
    mapping(bytes32 => string[]) internal stringArrayStorage;
    mapping(bytes32 => address[]) internal addressArrayStorage;
    mapping(bytes32 => bytes[]) internal bytesArrayStorage;
    mapping(bytes32 => bool[]) internal boolArrayStorage;
    mapping(bytes32 => int256[]) internal intArrayStorage;
    mapping(bytes32 => bytes32[]) internal bytes32ArrayStorage;

    function isInitialized() public view returns(bool) {
      return boolStorage[keccak256(abi.encodePacked("isInitialized"))];
    }

    function setInitialized(bool _status) internal {
      boolStorage[keccak256(abi.encodePacked("isInitialized"))] = _status;
    }
}
