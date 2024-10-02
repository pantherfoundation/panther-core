// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../errMsgs/CachedRootsErrMsgs.sol";

/**
 * @title RingBufferRootCache
 * @notice This contract caches roots in a ring buffer and provides functionalities to check if a root is in the cache.
 * @dev The contract allows caching of up to 256 roots, and it manages the storage of roots using a mapping from
 * cache indices to root values. The cached roots can be queried for statistics, and individual roots can be checked
 * for their presence in the cache. All storage parameters are initialized to zero, so no constructor initialization
 * is required.
 */
abstract contract RingBufferRootCache {
    // Must be a power of 2
    uint256 private constant CACHE_SIZE = 2 ** 8;
    uint256 private constant CACHE_INDEX_MASK = CACHE_SIZE - 1;

    uint256 public constant UNDEFINED_CACHE_INDEX = 0xFFFF;

    // Initial value of all storage params is 0.
    // So, no initialization in `constructor` required.

    /// @dev Mapping from cache "index" to cached root value
    mapping(uint256 => bytes32) private _cachedRoots;

    // Total number of roots cached so far
    uint64 private _cachedRootsCounter;

    // Value of _cachedRootsCounter after the latest cache reset
    uint64 private _cacheStartPos;

    /**
     * @notice Retrieves statistics about the cached roots.
     * @return numRootsCached The number of roots currently cached.
     * @return latestCacheIndex The index of the latest cached root.
     * @dev Reverts with an error message if no roots have been cached yet.
     */
    function getCacheStats()
        external
        view
        returns (uint256 numRootsCached, uint256 latestCacheIndex)
    {
        require(_cachedRootsCounter != 0, ERR_NO_ROOT_IS_ADDED);

        uint256 nextInd = _getCacheNextIndex(
            _cachedRootsCounter,
            _cacheStartPos
        );

        if (nextInd == 0) {
            latestCacheIndex = CACHE_SIZE - 1;
        } else {
            latestCacheIndex = --nextInd;
        }

        numRootsCached = _getCachedRootsNum(
            _cachedRootsCounter,
            _cacheStartPos
        );
    }

    /**
     * @notice Checks if a specific root is present in the cache.
     * @param root The root to check for presence in the cache.
     * @param cacheIndex The index of the cache to check.
     * @return isCached A boolean indicating whether the root is cached or not.
     * @dev If the cacheIndex is set to UNDEFINED_CACHE_INDEX, the function iterates through all cached roots.
     * Reverts with an error message if the cacheIndex is out of range.
     */
    function isCachedRoot(
        bytes32 root,
        uint256 cacheIndex
    ) public view returns (bool isCached) {
        uint256 nextPos = _cachedRootsCounter;
        // Definitely NOT in the cache, if no roots have been cached yet
        if (nextPos == 0) return false;

        isCached = false;
        uint256 startPos = _cacheStartPos;
        uint256 rootsNum = _getCachedRootsNum(nextPos, startPos);

        if (cacheIndex == UNDEFINED_CACHE_INDEX) {
            // Iterate through cached roots, starting from the newest one
            uint256 endPos = nextPos - rootsNum;
            while (!isCached && nextPos > endPos) {
                unchecked {
                    nextPos--;
                }
                if (
                    _cachedRoots[_getCacheNextIndex(nextPos, startPos)] == root
                ) {
                    isCached = true;
                }
            }
        } else {
            // Check against the value cached at the given index
            require(cacheIndex < rootsNum, ERR_INDEX_NOT_IN_RANGE);
            isCached = _cachedRoots[cacheIndex] == root;
        }
    }

    /**
     * @notice Caches a new root in the ring buffer.
     * @param root The root to be cached.
     * @return cacheIndex The index in the cache where the root has been stored.
     */
    function cacheNewRoot(bytes32 root) internal returns (uint256 cacheIndex) {
        cacheIndex = _addRootToCache(root);
    }

    /// Private functions follow

    /**
     * @dev Adds a root to the cache and returns the cache index.
     * @param root The root to be added to the cache.
     * @return cacheIndex The index in the cache where the root has been stored.
     */

    function _addRootToCache(
        bytes32 root
    ) private returns (uint256 cacheIndex) {
        uint64 counter = _cachedRootsCounter;
        uint64 startPos = _cacheStartPos;

        cacheIndex = _getCacheNextIndex(counter, startPos);
        _cachedRoots[cacheIndex] = root;

        _cachedRootsCounter = ++counter;
    }

    /**
     * @dev Gets the number of cached roots since the last reset.
     * @param counter The current count of cached roots.
     * @param startPos The starting position for counting cached roots.
     * @return The number of roots cached since the last reset.
     * @dev Calling code MUST ensure `counter >= startPos`
     */
    function _getCachedRootsNum(
        uint256 counter,
        uint256 startPos
    ) private pure returns (uint256) {
        uint256 nSinceStart = counter - startPos;
        return (nSinceStart > CACHE_SIZE) ? CACHE_SIZE : nSinceStart;
    }

    /**
     * @dev Gets the next index for caching based on the current count and starting position.
     * @param counter The current count of cached roots.
     * @param startPos The starting position for indexing.
     * @return The next index to use for caching.
     * @dev Calling code MUST ensure `counter >= startPos`
     */
    function _getCacheNextIndex(
        uint256 counter,
        uint256 startPos
    ) private pure returns (uint256) {
        return (counter - startPos) & CACHE_INDEX_MASK;
    }
}
