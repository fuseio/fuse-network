pragma solidity ^0.4.24;

import "./abstracts/BlockRewardBase.sol";
import "./BlockRewardStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/**
* @title Contract handling block reward logic
*/
contract BlockReward is BlockRewardStorage, BlockRewardBase {
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
    require(msg.sender == systemAddress());
    _;
  }

  /**
  * @dev Function to be called on contract initialization
  * @param _reward block reward amount on each block
  */
  function initialize(uint256 _reward) public returns(bool) {
    require(!isInitialized());
    setSystemAddress(0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
    setReward(_reward);
    setInitialized(true);
    return isInitialized();
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

    address[] memory receivers = new address[](benefactors.length);
    uint256[] memory rewards = new uint256[](receivers.length);

    receivers[0] = benefactors[0];
    rewards[0] = getReward();

    emit Rewarded(receivers, rewards);

    return (receivers, rewards);
  }
}
