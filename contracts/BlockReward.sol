pragma solidity ^0.4.24;

import "./abstracts/BlockRewardBase.sol";
import "./eternal-storage/EternalStorage.sol";
import "./ProxyStorage.sol";
import "./Consensus.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling block reward logic
*/
contract BlockReward is EternalStorage, BlockRewardBase {
  using SafeMath for uint256;

  /**
  * @dev This event will be emitted every block, describing the rewards given
  * @param receivers array of addresses to reward
  * @param rewards array of balance increases corresponding to the receivers array
  */
  event Rewarded(address[] receivers, uint256[] rewards);

  /**
  * @dev This modifier verifies that msg.sender is the system address (EIP96)
  */
  modifier onlySystem() {
    require(msg.sender == getSystemAddress());
    _;
  }

  /**
  * @dev This modifier verifies that msg.sender is the owner of the contract
  */
  modifier onlyOwner() {
    require(msg.sender == addressStorage[keccak256(abi.encodePacked("owner"))]);
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _reward block reward amount on each block
  */
  function initialize(uint256 _reward) public onlyOwner {
    require(!isInitialized());
    setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    setReward(_reward);
    setInitialized(true);
  }

  /**
  * @dev Function called to produce the reward on each block
  * @param benefactors array of addresses representing benefectors to be considered for reward
  * @param kind array of reward types. We support only arrays with one item and type = 0 (Author - Reward attributed to the block author)
  * See https://wiki.parity.io/Block-Reward-Contract.html
  */
  function reward(address[] benefactors, uint16[] kind) external onlySystem returns (address[], uint256[]) {
    require(benefactors.length == kind.length);
    require(benefactors.length == 1);
    require(kind[0] == 0);

    Consensus(ProxyStorage(getProxyStorage()).getConsensus()).cycle();

    address[] memory receivers = new address[](benefactors.length);
    uint256[] memory rewards = new uint256[](receivers.length);

    receivers[0] = benefactors[0];
    rewards[0] = getReward();

    emit Rewarded(receivers, rewards);

    return (receivers, rewards);
  }

  function setSystemAddress(address _newAddress) private {
    addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))] = _newAddress;
  }

  function getSystemAddress() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("SYSTEM_ADDRESS"))];
  }

  function setReward(uint256 _reward) private {
    require(_reward >= 0);
    uintStorage[keccak256(abi.encodePacked("reward"))] = _reward;
  }

  function getReward() public view returns(uint256) {
    return uintStorage[keccak256(abi.encodePacked("reward"))];
  }

  function getProxyStorage() public view returns(address) {
    return addressStorage[keccak256(abi.encodePacked("proxyStorage"))];
  }
}
