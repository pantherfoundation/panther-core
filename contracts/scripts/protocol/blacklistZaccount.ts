// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';
import yargs from 'yargs';

import zAccountRegistryABI from '../../deployments/ARCHIVE/staging/mumbai/ZAccountsRegistry_Implementation.json';

import {
    CommonCLIArgs,
    validateInput,
    setupContract,
    logScriptDetails,
    executeTransaction,
    logTransactionDetails,
} from './contractInteractionUtils';

type CLIArgs = CommonCLIArgs & {
    zAccountId: number;
    blacklist: boolean;
};

const argv = yargs(process.argv)
    .option('address', {
        alias: 'a',
        description: 'The address of the zAccountRegistry smart contract',
        type: 'string',
        demandOption: true,
    })
    .option('privateKey', {
        alias: 'pk',
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

async function main() {
    try {
        validateInput(argv, () => {
            if (isNaN(argv.zAccountId) || argv.zAccountId < 0) {
                throw new Error('Invalid zAccountId');
            }
        });

        logScriptDetails(
            `Preparing to ${argv.blacklist ? '' : 'un'}blacklist zAccountId: ${
                argv.zAccountId
            }`,
        );

        const contract = setupContract(argv, zAccountRegistryABI.abi);
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
