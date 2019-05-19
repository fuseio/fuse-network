pragma solidity ^0.4.24;

import "./BasicBlockReward.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Reward is BasicBlockReward {
  using SafeMath for uint256;

  event Rewarded(address[] receivers, uint256[] rewards);

  modifier onlySystem() {
    require(msg.sender == systemAddress());
    _;
  }

  function initialize(uint256 _reward, address _owner) public returns(bool) {
    require(!isInitialized());
    require(_owner != address(0));
    setSystemAddress();
    setOwner(_owner);
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
