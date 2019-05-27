pragma solidity ^0.4.24;

import "./abstracts/BlockRewardBase.sol";
import "./BlockRewardStorage.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BlockReward is BlockRewardStorage, BlockRewardBase {
  using SafeMath for uint256;

  event Rewarded(address[] receivers, uint256[] rewards);

  modifier onlySystem() {
    require(msg.sender == systemAddress());
    _;
  }

  function initialize(uint256 _reward) public returns(bool) {
    require(!isInitialized());
    setSystemAddress();
    setReward(_reward);
    setInitialized(true);
    return isInitialized();
  }

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
