// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation
pragma solidity ^0.8.19;

import "../../../errMsgs/CachedRootsErrMsgs.sol";

/// @dev It caches roots in a ring buffer and checks if a root is in the cache
abstract contract RingBufferRootCache {
    // slither-disable-next-line shadowing-state unused-state
    uint256[10] private __gap;

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

    function cacheNewRoot(bytes32 root) internal returns (uint256 cacheIndex) {
        cacheIndex = _addRootToCache(root);
    }

    /// Private functions follow

    function _addRootToCache(
        bytes32 root
    ) private returns (uint256 cacheIndex) {
        uint64 counter = _cachedRootsCounter;
        uint64 startPos = _cacheStartPos;

        cacheIndex = _getCacheNextIndex(counter, startPos);
        _cachedRoots[cacheIndex] = root;

        _cachedRootsCounter = ++counter;
    }

    // Calling code MUST ensure `counter >= startPos`
    function _getCachedRootsNum(
        uint256 counter,
        uint256 startPos
    ) private pure returns (uint256) {
        uint256 nSinceStart = counter - startPos;
        return (nSinceStart > CACHE_SIZE) ? CACHE_SIZE : nSinceStart;
    }

    // Calling code MUST ensure `counter >= startPos`
    function _getCacheNextIndex(
        uint256 counter,
        uint256 startPos
    ) private pure returns (uint256) {
        return (counter - startPos) & CACHE_INDEX_MASK;
    }

    // slither-disable-next-line shadowing-state unused-state
    uint256[10] private _trailingGap;
}
