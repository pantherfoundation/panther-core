// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';
import yargs from 'yargs';

import zAccountRegistryABI from '../../deployments/ARCHIVE/staging/mumbai/ZAccountsRegistry_Implementation.json';

type CLIArgs = {
    address: string;
    owner: string;
    zAccountId: number;
    blacklist: boolean;
    execute: boolean;
    rpc: string;
};

const argv = yargs(process.argv)
    .option('address', {
        alias: 'a',
        description: 'The address of the zAccountRegistry smart contract',
        type: 'string',
        demandOption: true,
    })
    .option('owner', {
        alias: 'o',
        description: 'The private key of the smart contract owner',
        type: 'string',
    })
    .option('zAccountId', {
        alias: 'z',
        description: 'The zAccountID to be blacklisted or unblacklisted',
        type: 'number',
        demandOption: true,
    })
    .option('blacklist', {
        alias: 'b',
        description:
            'Boolean to indicate whether to blacklist (true) or unblacklist (false)',
        type: 'boolean',
        demandOption: true,
    })
    .option('execute', {
        alias: 'e',
        description: 'Execute the transaction',
        type: 'boolean',
        default: false,
    })
    .option('rpc', {
        alias: 'r',
        description: 'The RPC URL',
        type: 'string',
        default: 'https://rpc-amoy.polygon.technology',
    })
    .help()
    .alias('help', 'h').argv as CLIArgs;

function isValidUrl(url: string): boolean {
    try {
        new URL(url);
        return true;
    } catch (err) {
        return false;
    }
}

function validateInput(args: CLIArgs): void {
    if (!ethers.utils.isAddress(args.address)) {
        throw new Error('Invalid contract address');
    }
    if (isNaN(args.zAccountId) || args.zAccountId < 0) {
        throw new Error('Invalid zAccountId');
    }
    if (!isValidUrl(args.rpc)) {
        throw new Error('Invalid RPC URL');
    }
    if (args.execute && !args.owner) {
        throw new Error('Owner private key is required to execute transaction');
    }
}

function logScriptDetails(args: CLIArgs): void {
    console.log(
        `Preparing to ${args.blacklist ? '' : 'un'}blacklist zAccountId: ${
            args.zAccountId
        }`,
    );
    console.log(`Using contract at address: ${args.address}`);
}

function setupContract(args: CLIArgs) {
    const provider = new ethers.providers.JsonRpcProvider(args.rpc);
    const signerOrProvider = args.execute
        ? new ethers.Wallet(args.owner, provider)
        : provider;
    return new ethers.Contract(
        args.address,
        zAccountRegistryABI.abi,
        signerOrProvider,
    );
}

function logTransactionDetails(
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

async function prepareTransaction(
    contract: ethers.Contract,
    zAccountId: number,
    blacklist: boolean,
): Promise<ethers.PopulatedTransaction> {
    return await contract.populateTransaction.updateBlacklistForZAccountId(
        zAccountId,
        blacklist,
    );
}

async function executeTransaction(
    wallet: ethers.Wallet,
    txData: ethers.PopulatedTransaction,
): Promise<void> {
    const txResponse = await wallet.sendTransaction(txData);
    console.log('Transaction Hash:', txResponse.hash);
    await txResponse.wait();
    console.log('Transaction confirmed.');
}

async function main() {
    try {
        validateInput(argv);

        logScriptDetails(argv);

        const contract = setupContract(argv);
        const txData = await prepareTransaction(
            contract,
            argv.zAccountId,
            argv.blacklist,
        );

        logTransactionDetails(txData, contract.address);

        if (argv.execute) {
            await executeTransaction(contract.signer as ethers.Wallet, txData);
        }
    } catch (error: any) {
        console.error('An error occurred:', error.message);
        if (error.code) {
            console.error('Error code:', error.code);
        }
        process.exit(1);
    }
}

main();
