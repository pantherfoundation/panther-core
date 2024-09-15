// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../utils/merkleTrees/DegenerateIncrementalBinaryTree.sol";

import "../../../../../../common/crypto/PoseidonHashers.sol";
import { HUNDRED_PERCENT } from "../../../../../../common/Constants.sol";

/**
 * @dev It handles "queues" of commitments to UTXOs (further - "UTXOs").
 * Queue is an ordered list of UTXOs. All UTXOs in a queue are supposed to be
 * processed at once.
 * To save gas, this contract
 * - stores the commitment to UTXOs in a queue (but not UTXOs) in the storage
 * - computes the commitment as the root of a degenerate tree (not binary one)
 * built from UTXOs the queue contains.
 * For every queue, it also records the amount of rewards associated with the
 * Queue (think of "reward for processing the queue").
 * If a queue gets fully populated with UTXOs, it is considered to be "closed".
 * No more UTXOs may be appended to that queue, and a new queue is created.
 * There may be many closed which pends processing. But one only partially
 * populated queue exists (it is always the most recently created queue).
 * Queues may be processed in any order (say, the 3rd queue may go before the
 * 1st one; and a fully populated queue may be processed after the partially
 * populated one).
 * The contract maintains the doubly-linked list of unprocessed queues.
 * The queue lifecycle is:
 * "Opened -> (optionally) Closed -> Processed (and deleted)."
 */
abstract contract BusQueues is DegenerateIncrementalBinaryTree {
    bytes32[50] private _startGap;

    uint256 internal constant QUEUE_MAX_LEVELS = 6;
    uint256 private constant QUEUE_MAX_SIZE = 2 ** QUEUE_MAX_LEVELS;
    // solhint-enable var-name-mixedcase

    /**
     * @param nUtxos Number of UTXOs in the queue
     * @param reward Rewards accumulated for the queue
     * @param firstUtxoBlock Block when the 1st UTXO was added to the queue
     * @param lastUtxoBlock Block when a UTXO was last added to the queue
     * @param prevLink Link to the previous unprocessed queue
     * @param nextLink Link to the next unprocessed queue
     * @dev If `prevLink` (`nextLink`) is 0, the unprocessed queue is the one
     * created right before (after) this queue, or no queues remain unprocessed,
     * which were created before (after) this queue. If the value is not 0, the
     * value is the unprocessed queue's ID adjusted by +1.
     */
    struct BusQueue {
        uint8 nUtxos;
        uint96 reward;
        uint40 firstUtxoBlock;
        uint40 lastUtxoBlock;
        uint32 prevLink;
        uint32 nextLink;
    }

    struct BusQueueRec {
        uint32 queueId;
        uint8 nUtxos;
        uint96 reward;
        uint96 potentialExtraReward;
        uint40 firstUtxoBlock;
        uint40 lastUtxoBlock;
        uint40 remainingBlocks;
        bytes32 commitment;
    }

    // Mapping from queue ID to queue params
    mapping(uint32 => BusQueue) internal _busQueues;
    // Mapping from queue ID to queue commitment
    mapping(uint32 => bytes32) private _busQueueCommitments;

    // ID of the next queue to create
    uint32 internal _nextQueueId;
    // Number of unprocessed queues
    uint32 internal _numPendingQueues;
    // Link to the oldest (created but yet) unprocessed queue
    // (if 0 - no such queue exists, otherwise the queue's ID adjusted by +1)
    uint32 internal _oldestPendingQueueLink;

    // Part (in 1/100th of 1%) of queue reward to be reserved for "premiums"
    uint16 private _reservationRate;
    // Part (in 1/100th of 1%) of a queue reward to be accrued as the premium
    // (i.e. an extra reward) for every block the queue pends processing
    uint16 private _premiumRate;

    // Minimum number of blocks an empty queue must pend processing.
    uint16 private _minEmptyQueueAge;

    // Unused yet part of queue rewards which were reserved for premiums
    int192 internal _netRewardReserve;

    // Emitted for every UTXO appended to a queue
    event UtxoBusQueued(
        bytes32 indexed utxo,
        uint256 indexed queueId,
        uint256 utxoIndexInBatch
    );

    // Emitted when a new queue is opened (it becomes the "current" one)
    event BusQueueOpened(uint256 queueId);

    // Emitted when a queue is registered as the processed one (and deleted)
    event BusQueueProcessed(uint256 indexed queueId);

    // Emitted when params of reward computation updated
    event BusQueueRewardParamsUpdated(
        uint256 reservationRate,
        uint256 premiumRate,
        uint256 minEmptyQueueAge
    );
    // Emitted when new reward "reserves" added
    event BusQueueRewardReserved(int256 extraReseve);
    // Emitted when (part of) reward "reserves" used
    event BusQueueRewardReserveUsed(int256 usage);

    // Emitted when queue reward increased w/o adding UTXOs
    event BusQueueRewardAdded(uint256 indexed queueId, uint256 accumReward);

    bytes32[50] private _endGap;

    modifier nonEmptyBusQueue(uint32 queueId) {
        require(_busQueues[queueId].nUtxos > 0, "BQ:EMPTY_QUEUE");
        _;
    }

    // The contract is intentionally written so, that explicit initialization of
    // storage variables is unneeded (zero values are implicitly initialized in
    // new storage slots).
    // To enable premiums or queue age limit, the `updateParams` call needed.

    // @return  reservationRate Part (in 1/100th of 1%) of every queue reward to
    // reserve for "premiums" (the remaining reward is "guaranteed" one)
    // @return premiumRate Part (in 1/100th of 1%) of a queue reward to accrue as
    // the premium for every block the queue pends processing
    // @return minEmptyQueueAge Min number of blocks an empty queue must pend
    // processing. For a partially filled queue, it declines linearly with the
    // number of queue's UTXOs. Full queues are immediately processable.
    function getParams()
        external
        view
        returns (
            uint16 reservationRate,
            uint16 premiumRate,
            uint16 minEmptyQueueAge
        )
    {
        reservationRate = _reservationRate;
        premiumRate = _premiumRate;
        minEmptyQueueAge = _minEmptyQueueAge;
    }

    function getBusQueuesStats()
        external
        view
        returns (
            uint32 curQueueId,
            uint32 numPendingQueues,
            uint32 oldestPendingQueueId,
            int192 newRewardReserve
        )
    {
        uint32 nextQueueId = _nextQueueId;
        require(nextQueueId != 0, "BT:NO_QUEUES");
        curQueueId = nextQueueId - 1;
        numPendingQueues = _numPendingQueues;
        oldestPendingQueueId = numPendingQueues == 0
            ? 0
            : _oldestPendingQueueLink - 1;
        newRewardReserve = _netRewardReserve;
    }

    function getBusQueue(
        uint32 queueId
    ) external view returns (BusQueueRec memory queue) {
        BusQueue memory q = _busQueues[queueId];
        require(
            queueId + 1 == _nextQueueId || q.nUtxos > 0,
            "BT:UNKNOWN_OR_PROCESSED_QUEUE"
        );
        (uint256 reward, uint256 premium, ) = _estimateRewarding(q);
        queue = BusQueueRec(
            queueId,
            q.nUtxos,
            uint96(reward),
            uint96(premium),
            q.firstUtxoBlock,
            q.lastUtxoBlock,
            _getQueueRemainingBlocks(q),
            _busQueueCommitments[queueId]
        );
    }

    // @param maxLength Maximum number of queues to return
    // @return queues Queues pending processing, starting from the oldest one
    function getOldestPendingQueues(
        uint32 maxLength
    ) external view returns (BusQueueRec[] memory queues) {
        uint256 nQueues = _numPendingQueues;
        if (nQueues > maxLength) nQueues = maxLength;
        queues = new BusQueueRec[](nQueues);

        uint32 nextLink = _oldestPendingQueueLink;
        for (uint256 i = 0; i < nQueues; i++) {
            uint32 queueId = nextLink - 1;
            BusQueue memory queue = _busQueues[queueId];

            queues[i].queueId = queueId;
            queues[i].nUtxos = queue.nUtxos;
            (uint256 reward, uint256 premium, ) = _estimateRewarding(queue);
            queues[i].reward = uint96(reward);
            queues[i].potentialExtraReward = uint96(premium);
            queues[i].firstUtxoBlock = queue.firstUtxoBlock;
            queues[i].lastUtxoBlock = queue.lastUtxoBlock;
            queues[i].remainingBlocks = _getQueueRemainingBlocks(queue);
            queues[i].commitment = _busQueueCommitments[queueId];

            nextLink = queue.nextLink == 0 ? nextLink + 1 : queue.nextLink;
        }

        return queues;
    }

    // @dev Refer to return values of the `getParam` function
    function _updateBusQueueRewardParams(
        uint16 reservationRate,
        uint16 premiumRate,
        uint16 minEmptyQueueAge
    ) internal {
        require(
            reservationRate <= HUNDRED_PERCENT &&
                premiumRate <= HUNDRED_PERCENT,
            "BQ:INVALID_PARAMS"
        );
        _reservationRate = reservationRate;
        _premiumRate = premiumRate;
        _minEmptyQueueAge = minEmptyQueueAge;

        emit BusQueueRewardParamsUpdated(
            reservationRate,
            premiumRate,
            minEmptyQueueAge
        );
    }

    /// @return firstQueueId ID of the queue which `utxos[0]` was added to
    /// @return firstIndexInFirstQueue Index of `utxos[0]` in the queue
    /// @dev Code that calls it MUST ensure utxos[i] < FIELD_SIZE
    /// If the current queue has no space left to add all UTXOs, a part of
    /// UTXOs only are added to the current queue until it gets full, then the
    /// remaining UTXOs are added to a new queue.
    /// Index of any UTXO (not just the 1st one) may be computed as follows:
    /// - index of UTXO in a queue increments by +1 with every new UTXO added,
    ///   (from 0 for the 1st UTXO in a queue up to `QUEUE_MAX_SIZE - 1`)
    /// - number of UTXOs added to the new queue (if there are such) equals to
    ///   `firstUtxoIndexInQueue + utxos[0].length - QUEUE_MAX_SIZE`
    /// - new queue (if created) has ID equal to `firstUtxoQueueId + 1`
    function _addUtxosToBusQueue(
        bytes32[] memory utxos,
        uint96 reward
    ) internal returns (uint32 firstQueueId, uint8 firstIndexInFirstQueue) {
        require(utxos.length < QUEUE_MAX_SIZE, "BQ:TOO_MANY_UTXOS");

        uint32 queueId;
        BusQueue memory queue;
        bytes32 commitment;
        {
            uint32 nextQueueId = _nextQueueId;
            if (nextQueueId == 0) {
                // Create the 1st queue
                (queueId, queue, commitment) = _createNewBusQueue();
                _oldestPendingQueueLink = queueId + 1;
            } else {
                // Read an existing queue from the storage
                queueId = nextQueueId - 1;
                queue = _busQueues[queueId];
                commitment = _busQueueCommitments[queueId];
            }
        }
        firstQueueId = queueId;
        firstIndexInFirstQueue = queue.nUtxos;

        // Block number overflow risk ignored
        uint40 curBlock = uint40(block.number);

        for (uint256 n = 0; n < utxos.length; n++) {
            if (queue.nUtxos == 0) queue.firstUtxoBlock = curBlock;

            bytes32 utxo = utxos[n];
            commitment = insertLeaf(utxo, commitment, queue.nUtxos == 0);
            emit UtxoBusQueued(utxo, queueId, queue.nUtxos);
            queue.nUtxos += 1;

            // If the current queue gets fully populated, switch to a new queue
            if (queue.nUtxos == QUEUE_MAX_SIZE) {
                // Part of the reward relates to the populated queue
                uint96 rewardUsed = uint96(
                    (uint256(reward) * (n + 1)) / utxos.length
                );
                queue.reward += rewardUsed;
                // Remaining reward is for the new queue
                reward -= rewardUsed;

                queue.lastUtxoBlock = curBlock;
                _busQueues[queueId] = queue;
                _busQueueCommitments[queueId] = commitment;

                // Create a new queue
                (queueId, queue, commitment) = _createNewBusQueue();
            }
        }

        if (queue.nUtxos > 0) {
            queue.reward += reward;
            queue.lastUtxoBlock = curBlock;
            _busQueues[queueId] = queue;
            _busQueueCommitments[queueId] = commitment;
        }
    }

    // It delete the processed queue and returns the queue params
    function _setBusQueueAsProcessed(
        uint32 queueId
    )
        internal
        nonEmptyBusQueue(queueId)
        returns (bytes32 commitment, uint8 nUtxos, uint96 reward)
    {
        BusQueue memory queue = _busQueues[queueId];
        require(_getQueueRemainingBlocks(queue) == 0, "BQT:IMMATURE_QUEUE");

        commitment = _busQueueCommitments[queueId];
        nUtxos = queue.nUtxos;
        reward = uint96(_computeReward(queue));

        // Clear the storage for the processed queue
        _busQueues[queueId] = BusQueue(0, 0, 0, 0, 0, 0);
        _busQueueCommitments[queueId] = bytes32(0);

        _numPendingQueues -= 1;

        // If applicable, open a new queue (_nextQueueId can't be 0 here)
        uint32 curQueueId = _nextQueueId - 1;
        if (queueId == curQueueId) {
            (curQueueId, , ) = _createNewBusQueue();
        }

        // Compute and save links to previous, next, oldest unprocessed queues
        // (link, if unequal to 0, is the unprocessed queue's ID adjusted by +1)
        uint32 nextLink = queue.nextLink == 0 ? queueId + 2 : queue.nextLink;
        uint32 nextPendingQueueId = nextLink - 1;
        {
            uint32 prevLink;
            bool isOldestQueue = _oldestPendingQueueLink == queueId + 1;
            if (isOldestQueue) {
                prevLink = 0;
                _oldestPendingQueueLink = nextLink;
            } else {
                prevLink = queue.prevLink == 0 ? queueId : queue.prevLink;
                _busQueues[prevLink - 1].nextLink = nextLink;
            }
            _busQueues[nextPendingQueueId].prevLink = prevLink;
        }

        emit BusQueueProcessed(queueId);
    }

    function _addBusQueueReward(
        uint32 queueId,
        uint96 extraReward
    ) internal nonEmptyBusQueue(queueId) {
        require(extraReward > 0, "BQ:ZERO_REWARD");
        uint96 accumReward;
        unchecked {
            // Values are supposed to be too small to cause overflow
            accumReward = _busQueues[queueId].reward + extraReward;
            _busQueues[queueId].reward = accumReward;
        }
        emit BusQueueRewardAdded(queueId, accumReward);
    }

    function hash(
        bytes32 left,
        bytes32 right
    ) internal pure override returns (bytes32) {
        return PoseidonHashers.poseidonT3([left, right]);
    }

    function _createNewBusQueue()
        internal
        returns (uint32 newQueueId, BusQueue memory queue, bytes32 commitment)
    {
        newQueueId = _nextQueueId;

        // Store updated values in "old" storage slots
        unchecked {
            // Risks of overflow ignored
            _nextQueueId = newQueueId + 1;
            _numPendingQueues += 1;
        }
        // Explicit initialization of new storage slots to zeros is unneeded
        queue = BusQueue(0, 0, 0, 0, 0, 0);
        commitment = bytes32(0);

        emit BusQueueOpened(newQueueId);
    }

    // Returns the number of blocks to wait until a queue may be processed.
    // Always returns 0 for a fully populated queue (immediately processable).
    // For an empty queue it returns a meaningless value.
    function _getQueueRemainingBlocks(
        BusQueue memory queue
    ) internal view returns (uint40) {
        //! shouldn't be queue.nUtxos == QUEUE_MAX_SIZE ?
        if (queue.nUtxos >= QUEUE_MAX_SIZE) return 0;

        // Minimum "age" declines linearly to the number of UTXOs in the queue
        uint256 nEmptySeats = uint256(QUEUE_MAX_SIZE - queue.nUtxos);
        uint256 minAge = (nEmptySeats * _minEmptyQueueAge) / QUEUE_MAX_SIZE;

        uint256 maturityBlock = minAge + queue.firstUtxoBlock;

        return
            block.number >= maturityBlock
                ? 0 // Overflow risk ignored
                : uint40(maturityBlock - block.number);
    }

    function _computeReward(
        BusQueue memory queue
    ) internal returns (uint256 actReward) {
        (
            uint256 reward,
            uint256 premium,
            int256 netReserveChange
        ) = _estimateRewarding(queue);

        int192 reserve = _netRewardReserve;

        if (netReserveChange > 0) {
            _netRewardReserve = int96(reserve + netReserveChange);
            emit BusQueueRewardReserved(netReserveChange);
        }
        if (netReserveChange < 0) {
            _netRewardReserve = int96(reserve + netReserveChange);
            emit BusQueueRewardReserveUsed(netReserveChange);
        }

        actReward = reward + premium;
    }

    function _estimateRewarding(
        BusQueue memory queue
    )
        internal
        view
        returns (uint256 reward, uint256 premium, int256 netReserveChange)
    {
        // _reservationRate MUST be less than HUNDRED_PERCENT ...
        uint256 contrib = (uint256(queue.reward) * _reservationRate) /
            HUNDRED_PERCENT;
        // ... so this can't underflow
        reward = uint256(queue.reward) - contrib;
        uint256 pendBlocks = block.number - queue.firstUtxoBlock;

        premium =
            (uint256(queue.reward) * pendBlocks * _premiumRate) /
            HUNDRED_PERCENT;
        // positive/negative value means "supply"/"demand" to/from reserves
        netReserveChange = int256(contrib) - int256(premium);
    }
}
