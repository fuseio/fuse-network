// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IBlockReward.sol";
import "./interfaces/IConsensus.sol";
import "./ProxyStorage.sol";

/// @title StakingRewards
/// @notice Records validator/user reward weights per cycle and allows users to claim their proportional ETH rewards.
/// @dev The block reward contract records weights. The owner/operator funds and finalizes each cycle reward.
contract StakingRewards is ReentrancyGuard {
    using Math for uint256;

    /// @notice Hard ceiling for `maxReceivers`.
    /// @dev BlockReward.STAKING_RECORD_GAS_LIMIT is sized to record this many receivers into fresh storage slots.
    uint256 public constant MAX_RECEIVERS_LIMIT = 1000;

    /// @notice Address of the trusted block reward contract.
    /// @dev Only this address can call `recordBlockReward`.
    address public immutable blockReward;

    /// @notice Contract owner.
    address public owner;

    /// @notice Optional operator allowed to finalize cycle rewards.
    address public operator;

    /// @notice Whether reward recording and cycle finalization are paused.
    /// @dev When paused, `recordBlockReward` calls are ignored and `finalizeCycleReward` reverts.
    /// Claims of already finalized cycles keep working.
    bool public paused;

    /// @notice Maximum number of receivers recorded per `recordBlockReward` call.
    /// @dev Bounds the gas and the new storage slots one block can cost. Receivers past the limit are ignored.
    uint256 public maxReceivers;

    /// @notice Minimum weight a receiver needs to be recorded.
    /// @dev Lets the owner ignore dust delegations, so they cost no storage and don't count toward `maxReceivers`.
    uint256 public minRecordWeight;

    /// @notice User reward weight per cycle.
    /// @dev cycle => user => weight.
    mapping(uint256 => mapping(address => uint256)) public userCycleWeights;

    /// @notice Total reward weight recorded for each cycle.
    /// @dev Used as the denominator when calculating proportional rewards.
    mapping(uint256 => uint256) public totalCycleWeights;

    /// @notice ETH reward amount assigned to each cycle.
    /// @dev cycle => reward amount in wei.
    mapping(uint256 => uint256) public cycleRewards;

    /// @notice Whether a cycle reward has been finalized.
    /// @dev Users can only claim rewards for finalized cycles.
    mapping(uint256 => bool) public cycleFinalized;

    error NotBlockReward();
    error NotOperatorOrOwner();
    error NotOwner();
    error ZeroAddress();
    error ZeroReward();
    error CycleAlreadyFinalized();
    error CycleNotFinalized();
    error NoRewardsToClaim();
    error NoTotalWeight();
    error RewardTransferFailed();
    error ContractPaused();
    error CycleNotEnded();
    error InvalidMaxReceivers();

    /// @notice Emitted when reward weights are recorded for a cycle.
    /// @param cycle The cycle being recorded.
    /// @param totalWeightAdded The total valid weight added during this call.
    /// @param receiversLength Number of receivers passed in.
    /// @param rewardWeightsLength Number of reward weights passed in.
    /// @param recordedCount Number of receivers actually recorded.
    event BlockRewardRecorded(
        uint256 indexed cycle,
        uint256 totalWeightAdded,
        uint256 receiversLength,
        uint256 rewardWeightsLength,
        uint256 recordedCount
    );

    /// @notice Emitted when a cycle reward is funded and finalized.
    /// @param cycle The finalized cycle.
    /// @param rewardAmount The ETH reward amount assigned to the cycle.
    event CycleRewardFinalized(
        uint256 indexed cycle,
        uint256 rewardAmount
    );

    /// @notice Emitted when a user claims a reward.
    /// @param user The user claiming the reward.
    /// @param cycle The cycle being claimed.
    /// @param rewardAmount The ETH amount claimed.
    /// @param userWeight The user's recorded weight for the cycle.
    event RewardClaimed(
        address indexed user,
        uint256 indexed cycle,
        uint256 rewardAmount,
        uint256 userWeight
    );

    /// @notice Emitted when the operator is updated.
    /// @param oldOperator Previous operator address.
    /// @param newOperator New operator address.
    event OperatorUpdated(address indexed oldOperator, address indexed newOperator);

    /// @notice Emitted when ownership is transferred.
    /// @param oldOwner Previous owner address.
    /// @param newOwner New owner address.
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when the paused state is updated.
    /// @dev Not named `Paused`, which OpenZeppelin's Pausable emits with an `address` argument.
    /// @param paused The new paused state.
    event PauseUpdated(bool paused);

    /// @notice Emitted when the recording limits are updated.
    /// @param maxReceivers New maximum number of receivers recorded per call.
    /// @param minRecordWeight New minimum weight a receiver needs to be recorded.
    event RecordLimitsUpdated(uint256 maxReceivers, uint256 minRecordWeight);

    /// @dev Restricts access to the block reward contract.
    modifier onlyBlockReward() {
        if (msg.sender != blockReward) revert NotBlockReward();
        _;
    }

    /// @dev Restricts access to the owner or operator.
    modifier onlyOperatorOrOwner() {
        if (msg.sender != owner && msg.sender != operator) revert NotOperatorOrOwner();
        _;
    }

    /// @dev Restricts access to the owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @dev Restricts access when the contract is paused.
    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /// @notice Deploys the staking rewards contract.
    /// @param _blockReward Address of the trusted block reward contract.
    /// @param _operator Address of the initial operator.
    constructor(address _blockReward, address _operator) {
        if (_blockReward == address(0)) revert ZeroAddress();
        if (_operator == address(0)) revert ZeroAddress();

        blockReward = _blockReward;
        owner = msg.sender;
        operator = _operator;
        maxReceivers = MAX_RECEIVERS_LIMIT;
    }

    /// @notice Updates the operator address.
    /// @dev Can only be called by the owner.
    /// @param newOperator New operator address.
    function setOperator(address newOperator) external onlyOwner {
        if (newOperator == address(0)) revert ZeroAddress();
        
        address oldOperator = operator;
        operator = newOperator;

        emit OperatorUpdated(oldOperator, newOperator);
    }

    /// @notice Transfers ownership to a new owner.
    /// @dev Can only be called by the current owner.
    /// @param newOwner New owner address.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();

        address oldOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Pauses or unpauses reward recording and cycle finalization.
    /// @dev When paused, `recordBlockReward` calls are ignored and `finalizeCycleReward` reverts.
    /// Users can still claim cycles that were already finalized.
    function setPaused(bool newPauseValue) external onlyOwner {
        paused = newPauseValue;

        emit PauseUpdated(newPauseValue);
    }

    /// @notice Updates the limits applied when recording a block's receivers.
    /// @dev Can only be called by the owner.
    /// @param newMaxReceivers Maximum number of receivers recorded per call (1 to MAX_RECEIVERS_LIMIT).
    /// @param newMinRecordWeight Minimum weight a receiver needs to be recorded.
    function setRecordLimits(uint256 newMaxReceivers, uint256 newMinRecordWeight) external onlyOwner {
        if (newMaxReceivers == 0 || newMaxReceivers > MAX_RECEIVERS_LIMIT) revert InvalidMaxReceivers();

        maxReceivers = newMaxReceivers;
        minRecordWeight = newMinRecordWeight;

        emit RecordLimitsUpdated(newMaxReceivers, newMinRecordWeight);
    }

    /// @notice Records user reward weights for a cycle.
    /// @dev
    /// Does not revert if `receivers.length != rewardWeights.length`.
    /// Instead, it processes only the smaller length.
    ///
    /// Invalid entries are skipped:
    /// - receiver is address(0)
    /// - weight is 0 or below `minRecordWeight`
    ///
    /// At most `maxReceivers` entries are recorded; the rest are ignored. The validator comes first in the
    /// list, so it is always recorded.
    ///
    /// This protects the system from full-call reverts caused by bad individual entries, and bounds the gas
    /// and storage growth an unbounded delegator list could otherwise cause on every block.
    ///
    /// @param cycle The cycle being recorded.
    /// @param receivers List of reward receivers.
    /// @param rewardWeights List of corresponding reward weights.
    function recordBlockReward(
        uint256 cycle,
        address[] calldata receivers,
        uint256[] calldata rewardWeights
    ) external onlyBlockReward {
        if (cycleFinalized[cycle]) return;

        if (paused) return;

        (uint256 totalWeightAdded, uint256 recordedCount) = _recordWeights(
            userCycleWeights[cycle],
            receivers,
            rewardWeights
        );

        if (totalWeightAdded != 0) {
            totalCycleWeights[cycle] += totalWeightAdded;
        }

        emit BlockRewardRecorded(
            cycle,
            totalWeightAdded,
            receivers.length,
            rewardWeights.length,
            recordedCount
        );
    }

    /// @notice Funds and finalizes a cycle reward.
    /// @dev
    /// Only cycles that have ended can be finalized, so every block of the cycle has been recorded.
    /// Once finalized, no more weights can be added for that cycle.
    /// Users can only claim after the cycle has been finalized.
    ///
    /// This prevents users from claiming before the final reward amount is known.
    ///
    /// @param cycle The cycle to finalize (its start block).
    function finalizeCycleReward(uint256 cycle)
        external
        payable
        onlyOperatorOrOwner
        whenNotPaused
    {
        if (msg.value == 0) revert ZeroReward();
        if (cycle >= _currentCycleStartBlock()) revert CycleNotEnded();
        if (cycleFinalized[cycle]) revert CycleAlreadyFinalized();
        if (totalCycleWeights[cycle] == 0) revert NoTotalWeight();

        cycleRewards[cycle] = msg.value;
        cycleFinalized[cycle] = true;

        emit CycleRewardFinalized(cycle, msg.value);
    }

    /// @notice Claims rewards for multiple finalized cycles.
    /// @dev Reverts if any cycle in the list is not claimable by the caller.
    /// @param cycles List of cycle IDs to claim.
    function claimRewards(uint256[] calldata cycles) external nonReentrant {
        uint256 length = cycles.length;

        for (uint256 i; i < length; ) {
            _claimReward(cycles[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Claims reward for one finalized cycle.
    /// @param cycle The cycle to claim.
    function claimReward(uint256 cycle) external nonReentrant {
        _claimReward(cycle);
    }

    /// @notice Returns a user's pending reward for a cycle.
    /// @dev Returns 0 if the cycle is not finalized, user has no weight, or total weight is 0.
    /// @param user The user address.
    /// @param cycle The cycle ID.
    /// @return rewardAmount The pending ETH reward amount in wei.
    function pendingReward(address user, uint256 cycle)
        external
        view
        returns (uint256 rewardAmount)
    {
        if (!cycleFinalized[cycle]) return 0;

        uint256 userWeight = userCycleWeights[cycle][user];
        if (userWeight == 0) return 0;

        uint256 totalWeight = totalCycleWeights[cycle];
        if (totalWeight == 0) return 0;

        rewardAmount = Math.mulDiv(cycleRewards[cycle], userWeight, totalWeight);
    }

    /// @notice Internal reward claim logic.
    /// @dev
    /// Clears the user's cycle weight before transferring ETH to prevent re-claiming.
    /// Uses `call` instead of `transfer` to avoid the 2300 gas stipend limitation.
    /// Each claim rounds down, so up to 1 wei per claim stays in the contract.
    ///
    /// @param cycle The cycle to claim.
    function _claimReward(uint256 cycle) internal {
        if (!cycleFinalized[cycle]) revert CycleNotFinalized();

        uint256 userWeight = userCycleWeights[cycle][msg.sender];
        if (userWeight == 0) revert NoRewardsToClaim();

        uint256 totalWeight = totalCycleWeights[cycle];
        if (totalWeight == 0) revert NoTotalWeight();

        uint256 rewardAmount = Math.mulDiv(cycleRewards[cycle], userWeight, totalWeight);
        if (rewardAmount == 0) revert NoRewardsToClaim();

        userCycleWeights[cycle][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        if (!success) revert RewardTransferFailed();

        emit RewardClaimed(msg.sender, cycle, rewardAmount, userWeight);
    }

    /// @dev Adds each valid receiver's weight to `cycleWeights`, stopping once `maxReceivers` have been recorded.
    /// Processes only the shorter of the two lists.
    function _recordWeights(
        mapping(address => uint256) storage cycleWeights,
        address[] calldata receivers,
        uint256[] calldata rewardWeights
    ) internal returns (uint256 totalWeightAdded, uint256 recordedCount) {
        uint256 length = receivers.length < rewardWeights.length
            ? receivers.length
            : rewardWeights.length;
        uint256 maxCount = maxReceivers;
        uint256 minWeight = minRecordWeight;

        for (uint256 i; i < length && recordedCount < maxCount; ) {
            address receiver = receivers[i];
            uint256 weight = rewardWeights[i];

            if (receiver != address(0) && weight != 0 && weight >= minWeight) {
                cycleWeights[receiver] += weight;
                totalWeightAdded += weight;

                unchecked {
                    ++recordedCount;
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Start block of the consensus cycle in progress, which is the ID of the cycle being recorded.
    function _currentCycleStartBlock() internal view returns (uint256) {
        address proxyStorage = IBlockReward(blockReward).getProxyStorage();
        return IConsensus(ProxyStorage(proxyStorage).getConsensus()).getCurrentCycleStartBlock();
    }
}
