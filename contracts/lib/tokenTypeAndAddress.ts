// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

/**
 * Packs a token type and address into a uint256 value.
 *
 * @param tokenType A number representing the token type (uint8).
 * @param tokenAddress A string representing the Ethereum address (20 bytes).
 * @returns A bigint representing the packed uint256 value.
 */
export function packTokenTypeAndAddress(
    tokenType: number,
    tokenAddress: string,
): bigint {
    if (tokenType < 0 || tokenType > 255) {
        throw new Error('Token type must be a uint8 value (0-255).');
    }

    // Validate the token address
    if (!/^0x[0-9a-fA-F]{40}$/.test(tokenAddress)) {
        throw new Error('Invalid Ethereum address.');
    }

    // Convert token type to BigInt and shift left by 160 bits
    const tokenTypeBI = BigInt(tokenType) << 160n;

    // Convert token address to BigInt
    const tokenAddressBI = BigInt(tokenAddress);

    // Combine the two values
    return tokenTypeBI | tokenAddressBI;
}

/**
 * Extracts the token type and address from a combined uint256 value.
 *
 * @param tokenTypeAndAddress A BigNumber representing the combined uint256 value.
 * @returns An object containing the token type (uint8) and the token address.
 */
export function getTokenTypeAndAddress(tokenTypeAndAddress: bigint): {
    tokenType: number;
    tokenAddress: string;
} {
    // Extract the 8 MSB (tokenType) by shifting right 160 bits
    const tokenType = Number(tokenTypeAndAddress >> 160n);

    // Extract the 160 LSB (tokenAddress) using a bitwise AND
    const tokenAddressBigInt =
        tokenTypeAndAddress &
        BigInt('0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF');
    const tokenAddress = `0x${tokenAddressBigInt
        .toString(16)
        .padStart(40, '0')}`;

    return {tokenType, tokenAddress};
}
