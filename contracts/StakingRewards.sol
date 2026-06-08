// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title StakingRewards
/// @notice Records validator/user reward weights per cycle and allows users to claim their proportional ETH rewards.
/// @dev The block reward contract records weights. The owner/operator funds and finalizes each cycle reward.
contract StakingRewards {
    /// @notice Address of the trusted block reward contract.
    /// @dev Only this address can call `recordBlockReward`.
    address public immutable blockReward;

    /// @notice Contract owner.
    address public owner;

    /// @notice Optional operator allowed to finalize cycle rewards.
    address public operator;

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

    /// @notice Emitted when reward weights are recorded for a cycle.
    /// @param cycle The cycle being recorded.
    /// @param totalWeightAdded The total valid weight added during this call.
    /// @param receiversLength Number of receivers passed in.
    /// @param rewardWeightsLength Number of reward weights passed in.
    event BlockRewardRecorded(
        uint256 indexed cycle,
        uint256 totalWeightAdded,
        uint256 receiversLength,
        uint256 rewardWeightsLength
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

    /// @notice Deploys the staking rewards contract.
    /// @param _blockReward Address of the trusted block reward contract.
    /// @param _operator Address of the initial operator.
    constructor(address _blockReward, address _operator) {
        if (_blockReward == address(0)) revert ZeroAddress();

        blockReward = _blockReward;
        owner = msg.sender;
        operator = _operator;
    }

    /// @notice Updates the operator address.
    /// @dev Can only be called by the owner.
    /// @param newOperator New operator address.
    function setOperator(address newOperator) external onlyOwner {
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

    /// @notice Records user reward weights for a cycle.
    /// @dev
    /// Does not revert if `receivers.length != rewardWeights.length`.
    /// Instead, it processes only the smaller length.
    ///
    /// Invalid entries are skipped:
    /// - receiver is address(0)
    /// - weight is 0
    ///
    /// This protects the system from full-call reverts caused by bad individual entries.
    ///
    /// @param cycle The cycle being recorded.
    /// @param receivers List of reward receivers.
    /// @param rewardWeights List of corresponding reward weights.
    function recordBlockReward(
        uint256 cycle,
        address[] calldata receivers,
        uint256[] calldata rewardWeights
    ) external onlyBlockReward {
        if (cycleFinalized[cycle]) revert CycleAlreadyFinalized();

        uint256 receiversLength = receivers.length;
        uint256 weightLength = rewardWeights.length;

        uint256 length = receiversLength < weightLength
            ? receiversLength
            : weightLength;

        uint256 totalWeightAdded;

        for (uint256 i; i < length; ) {
            address receiver = receivers[i];
            uint256 weight = rewardWeights[i];

            if (receiver != address(0) && weight != 0) {
                userCycleWeights[cycle][receiver] += weight;
                totalWeightAdded += weight;
            }

            unchecked {
                ++i;
            }
        }

        if (totalWeightAdded != 0) {
            totalCycleWeights[cycle] += totalWeightAdded;
        }

        emit BlockRewardRecorded(
            cycle,
            totalWeightAdded,
            receiversLength,
            weightLength
        );
    }

    /// @notice Funds and finalizes a cycle reward.
    /// @dev
    /// Once finalized, no more weights can be added for that cycle.
    /// Users can only claim after the cycle has been finalized.
    ///
    /// This prevents users from claiming before the final reward amount is known.
    ///
    /// @param cycle The cycle to finalize.
    function finalizeCycleReward(uint256 cycle)
        external
        payable
        onlyOperatorOrOwner
    {
        if (msg.value == 0) revert ZeroReward();
        if (cycleFinalized[cycle]) revert CycleAlreadyFinalized();
        if (totalCycleWeights[cycle] == 0) revert NoTotalWeight();

        cycleRewards[cycle] = msg.value;
        cycleFinalized[cycle] = true;

        emit CycleRewardFinalized(cycle, msg.value);
    }

    /// @notice Claims rewards for multiple finalized cycles.
    /// @dev Reverts if any cycle in the list is not claimable by the caller.
    /// @param cycles List of cycle IDs to claim.
    function claimRewards(uint256[] calldata cycles) external {
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
    function claimReward(uint256 cycle) external {
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

        rewardAmount = (cycleRewards[cycle] * userWeight) / totalWeight;
    }

    /// @notice Internal reward claim logic.
    /// @dev
    /// Clears the user's cycle weight before transferring ETH to prevent re-claiming.
    /// Uses `call` instead of `transfer` to avoid the 2300 gas stipend limitation.
    ///
    /// @param cycle The cycle to claim.
    function _claimReward(uint256 cycle) internal {
        if (!cycleFinalized[cycle]) revert CycleNotFinalized();

        uint256 userWeight = userCycleWeights[cycle][msg.sender];
        if (userWeight == 0) revert NoRewardsToClaim();

        uint256 totalWeight = totalCycleWeights[cycle];
        if (totalWeight == 0) revert NoTotalWeight();

        uint256 rewardAmount = (cycleRewards[cycle] * userWeight) / totalWeight;
        if (rewardAmount == 0) revert NoRewardsToClaim();

        userCycleWeights[cycle][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        if (!success) revert RewardTransferFailed();

        emit RewardClaimed(msg.sender, cycle, rewardAmount, userWeight);
    }
}
