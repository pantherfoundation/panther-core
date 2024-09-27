// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';

export type CommonCLIArgs = {
    address: string;
    privateKey?: string;
    rpc: string;
    execute: boolean;
};

export function validateInput(
    args: CommonCLIArgs,
    contractSpecificValidations: () => void,
): void {
    if (!ethers.utils.isAddress(args.address)) {
        throw new Error('Invalid contract address');
    }
    if (!isValidUrl(args.rpc)) {
        throw new Error('Invalid RPC URL');
    }
    if (args.execute && !args.privateKey) {
        throw new Error('Private key is required to execute transaction');
    }

    contractSpecificValidations();
}

function isValidUrl(url: string): boolean {
    try {
        new URL(url);
        return true;
    } catch (err) {
        return false;
    }
}

export function setupContract(args: CommonCLIArgs, abi: any) {
    const provider = new ethers.providers.JsonRpcProvider(args.rpc);
    const signerOrProvider = args.execute
        ? new ethers.Wallet(args.privateKey!, provider)
        : provider;
    return new ethers.Contract(args.address, abi, signerOrProvider);
}

export function logTransactionDetails(
    txData: ethers.PopulatedTransaction,
    contractAddress: string,
): void {
    console.log('Transaction Input (Hex):', txData.data);
    const transactionInput = {
        to: contractAddress,
        data: txData.data,
        gasLimit: txData.gasLimit?.toString(),
        value: txData.value?.toString(),
    };
    console.log(
        'Transaction Input (JSON):',
        JSON.stringify(transactionInput, null, 2),
    );
}

export async function executeTransaction(
    wallet: ethers.Wallet,
    txData: ethers.PopulatedTransaction,
): Promise<void> {
    const txResponse = await wallet.sendTransaction(txData);
    console.log('Transaction Hash:', txResponse.hash);
    await txResponse.wait();
    console.log('Transaction confirmed.');
}

export function logScriptDetails(description: string): void {
    console.log(description);
}
