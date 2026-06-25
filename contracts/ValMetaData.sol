pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/math/Math.sol";
import "./interfaces/IConsensus.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";


contract ValidatorMetadata is EternalStorage {
    using SafeMath for uint256;

    bytes32 internal constant INIT_METADATA_DISABLED = keccak256("initMetadataDisabled");
    bytes32 internal constant OWNER = keccak256("owner");
    bytes32 internal constant PROXY_STORAGE = keccak256("proxyStorage");

    bytes32 internal constant CONTACT_EMAIL = "contactEmail";
    bytes32 internal constant VAL_NAME = "Name";
    bytes32 internal constant TG_ID = "telegreamID";
    bytes32 internal constant UPDATED_DATE = "updatedDate";

    event MetadataCleared(address indexed miningKey);
    event MetadataCreated(address indexed miningKey);
    event MetadataMoved(address indexed oldMiningKey, address indexed newMiningKey);


    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    function clearMetadata(address _miningKey)
        external
    {
        _deleteMetadata(_miningKey);
        emit MetadataCleared(_miningKey);
    }

    function proxyStorage() public view returns (address) {
        return addressStorage[PROXY_STORAGE];
    }

    function getValidatorName(address _miningKey) public view returns (
        bytes32 Name
    ) {
        Name = _getName(_miningKey);
    }

    function validators(address _miningKey) public view returns (
        bytes32 Name,
        bytes32 tgID,
        uint256 updatedDate,
        bytes32 contactEmail
    ) {
        return _validators(_miningKey);
    }

    function initMetadataDisabled() public view returns(bool) {
        return boolStorage[INIT_METADATA_DISABLED];
    }

    function initMetadata( // used for migration from v1.0 contracts
        bytes32 _Name,
        bytes32 _tgID,
        uint256 _updatedDate,
        address _miningKey
    ) public onlyOwner {
        require(!initMetadataDisabled());
        _setMetadata(
            _miningKey,
            _Name,
            _tgID,
            _updatedDate
        );
    }

    function initMetadataDisable() public onlyOwner {
        boolStorage[INIT_METADATA_DISABLED] = true;
    }

    function setMetaData(
        bytes32 _Name,
        bytes32 _tgID,
        bytes32 _contactEmail
    )
        public
    {
        address miningKey = msg.sender;
        _setMetadata(
            miningKey,
            _Name,
            _tgID,
            getTime()
        );
        _setContactEmail(miningKey, _contactEmail);
    }

    function getTime() public view returns(uint256) {
        return now;
    }

    function _getContactEmail(address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            "validators", _miningKey, CONTACT_EMAIL
        ))];
    }

    function _getName(address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            "validators", _miningKey, VAL_NAME
        ))];
    }

    function _getTGID(address _miningKey)
        private
        view
        returns(bytes32)
    {
        return bytes32Storage[keccak256(abi.encode(
            "validators", _miningKey, TG_ID
        ))];
    }

    function _getUpdatedDate( address _miningKey)
        private
        view
        returns(uint256)
    {
        return uintStorage[keccak256(abi.encode(
            "validators", _miningKey, UPDATED_DATE
        ))];
    }

    function _deleteMetadata(address _miningKey) private {
        string memory _store = "validators";
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, VAL_NAME))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, TG_ID))];
        delete uintStorage[keccak256(abi.encode(_store, _miningKey, UPDATED_DATE))];
        delete bytes32Storage[keccak256(abi.encode(_store, _miningKey, CONTACT_EMAIL))];
    }

    function _setContactEmail(address _miningKey, bytes32 _contactEmail) private {
        bytes32Storage[keccak256(abi.encode(
            "validators",
            _miningKey,
            CONTACT_EMAIL
        ))] = _contactEmail;
    }

    function _setName(address _miningKey, bytes32 _Name) private {
        bytes32Storage[keccak256(abi.encode(
            "validators",
            _miningKey,
            VAL_NAME
        ))] = _Name;
    }

    function _setTGID(address _miningKey, bytes32 _tgID) private {
        bytes32Storage[keccak256(abi.encode(
            "validators",
            _miningKey,
            TG_ID
        ))] = _tgID;
    }

    function _setUpdatedDate(
        
        address _miningKey,
        uint256 _updatedDate
    ) private {
        uintStorage[keccak256(abi.encode(
            "validators",
            _miningKey,
            UPDATED_DATE
        ))] = _updatedDate;
    }

    function _setMetadata(
        address _miningKey,
        bytes32 _Name,
        bytes32 _tgID,
        uint256 _updatedDate
    ) private {
        _setName(_miningKey, _Name);
        _setTGID(_miningKey, _tgID);
        _setUpdatedDate(_miningKey, _updatedDate);
    }

    function _validators(address _miningKey) private view returns (
        bytes32 Name,
        bytes32 tgID,
        uint256 updatedDate,
        bytes32 contactEmail
    ) {
        Name = _getName(_miningKey);
        tgID = _getTGID(_miningKey);
        updatedDate = _getUpdatedDate(_miningKey);
        contactEmail = _getContactEmail(_miningKey);
    }
}