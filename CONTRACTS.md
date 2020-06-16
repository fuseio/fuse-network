# Fuse Network Contracts

- [Consensus](#consensus)
- [Block Reward](#block-reward)
- [Voting](#voting)
- [Proxy Storage](#proxy-storage)

![Contracts Schema](https://storage.googleapis.com/sol2uml-storage/mainnet-0x970b9bb2c0444f5e81e9d0efb84c8ccdcdcaf84d.svg "Contracts Schema")

### Consensus

This contract is responsible for handling the network DPos consensus.

This contract is storing the current validator set and choosing a new validator set at the end of each cycle.

The logic for updating the validator set is to select a random snapshot from the snapshots taken during the cycle.

The snapshots taken, are of pending validators, who are those which staked more than the minimum stake needed to become a network validator. Therefore the contract is also responsible for staking, delegating and withdrawing those funds.

This contract is based on `non-reporting ValidatorSet` [described in Parity Wiki](https://wiki.parity.io/Validator-Set.html#non-reporting-contract).

### Block Reward

This contract is responsible for generating and distributing block rewards to the network validators according to the network specs (5% yearly inflation).

Another role of this contract is to call the snapshot/cycle logic on the Consensus contract.

This contract is based on `BlockReward` [described in Parity Wiki](https://wiki.parity.io/Block-Reward-Contract).

### Voting

This contract is responsible for opening new ballots and voting to accept/reject them.

Ballots are basically offers to change other network contracts implementation.

Only network validators can open new ballots, eveyone can vote on them, but only validators votes count when the ballot is closed.

Ballots are opened/closed on cycle end.

### Proxy Storage

This contract is responsible for holding network contracts implementation addresses and upgrading them if necessary (via ballot approval).
