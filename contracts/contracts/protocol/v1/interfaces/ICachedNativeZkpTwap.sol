// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.19;

interface ICachedNativeZkpTwap {
    /**
     * @notice Caches the current exchange rate from the native token to ZKP tokens.
     * @dev This public function retrieves the latest exchange rate between the native token and ZKP tokens
     *      by invoking the `getNativeRateInZkp` function with a standardized amount of 1 ether. The retrieved
     *      rate is then stored in the `cachedNativeRateInZkp` state variable for efficient access in subsequent
     *      operations. Caching the rate minimizes repetitive on-chain computations or external calls, thereby
     *      optimizing gas usage and improving contract performance.
     *
     *      **Key Operations:**
     *      1. **Rate Retrieval:**
     *         - Calls the `getNativeRateInZkp` function with an input amount of 1 ether to obtain the current
     *           exchange rate.
     *
     *      2. **Caching the Rate:**
     *         - Assigns the retrieved rate to the `cachedNativeRateInZkp` state variable.
     *
     *      **Usage Example:**
     *      ```solidity
     *      // Update the cached exchange rate before performing fee conversions
     *      feeMaster.cacheNativeToZkpRate();
     *
     *      // Use the cached rate in fee calculations
     *      uint256 zkpAmount = feeMaster.cachedNativeRateInZkp() * nativeAmount / 1 ether;
     *      ```
     */
    function cachedNativeRateInZkp() external view returns (uint256);

    /**
     * @dev Gets the rate of native token in terms of zkp token.
     * @param nativeAmount The amount of native token.
     * @return The rate of native token in zkp token.
     */
    function getNativeRateInZkp(
        uint256 nativeAmount
    ) external view returns (uint256);

    /**
     * @dev Gets the rate of zkp token in terms of native token.
     * @param zkpAmount The amount of zkp token.
     * @return The rate of zkp token in native token.
     */
    function getZkpRateInNative(
        uint256 zkpAmount
    ) external view returns (uint256);
}
