// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

/**
 * Calculate a unique nonce based on the provided callData and walletAddress,
 * and then retrieve the nonce from the EntryPoint contract.
 *
 * @param {any} callData - The data to be hashed.
 * @param {string} walletAddress - The address of the wallet.
 * @param {EntryPoint} entryPoint - The EntryPoint contract instance to interact with.
 * @returns {Promise<any>} - The nonce retrieved from the EntryPoint contract.
 */

import {EntryPoint} from '../../types/contracts';

export async function callculateAndGetNonce(
    callData,
    walletAddress: string,
    entryPoint: EntryPoint,
) {
    // Hash the provided callData using keccak256
    const hashedData = ethers.utils.keccak256(callData);

    // Extract the lowest 11 bytes of the hashed data to use as a nonce
    const lowestBytesAsNonce = '0x' + hashedData.slice(-22);

    // Call the getNonce function of the EntryPoint contract with the walletAddress and calculated nonce
    return await entryPoint.getNonce(
        walletAddress,
        lowestBytesAsNonce.toString(),
    );
}
