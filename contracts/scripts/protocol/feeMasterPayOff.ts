// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';
import yargs from 'yargs';

import {
    validateInput,
    CommonCLIArgs,
    setupContract,
    logScriptDetails,
    executeTransaction,
    logTransactionDetails,
} from './contractInteractionUtils';

type CLIArgs = CommonCLIArgs & {
    tokenAddress: string;
    receiver: string;
};

const argv = yargs(process.argv)
    .option('privateKey', {
        alias: 'pk',
        description: 'Private key of the user triggering the function',
        type: 'string',
    })
    .option('address', {
        alias: 'a',
        description: 'Address of the FeeMaster contract',
        type: 'string',
        demandOption: true,
    })
    .option('rpc', {
        alias: 'rpc',
        description: 'RPC endpoint to connect to the blockchain',
        type: 'string',
        demandOption: true,
    })
    .option('tokenAddress', {
        alias: 't',
        description: 'Address of the token (ZKP)',
        type: 'string',
        demandOption: true,
    })
    .option('receiver', {
        alias: 'r',
        description: 'Receiving address for the fees',
        type: 'string',
        demandOption: true,
    })
    .option('execute', {
        alias: 'e',
        description: 'Flag to execute or solely print the call data',
        type: 'boolean',
        default: false,
    })
    .help()
    .alias('help', 'h').argv as CLIArgs;

async function prepareTransaction(
    contract: ethers.Contract,
    tokenAddress: string,
    receiver: string,
): Promise<ethers.PopulatedTransaction> {
    return await contract.populateTransaction.payOff(tokenAddress, receiver);
}

const functionFragment =
    'function payOff(address tokenAddress, address receiver, uint256 amount) returns (uint256 debt)';

async function main() {
    try {
        validateInput(argv, () => {
            if (!ethers.utils.isAddress(argv.tokenAddress)) {
                throw new Error('Invalid token address');
            }
            if (!ethers.utils.isAddress(argv.receiver)) {
                throw new Error('Invalid receiver address');
            }
        });

        logScriptDetails(
            `Executing payOff on FeeMaster at ${argv.address} for Token: ${argv.tokenAddress} to Receiver: ${argv.receiver}`,
        );

        const iface = new ethers.utils.Interface([functionFragment]);

        const contract = setupContract(argv, iface);
        const txData = await prepareTransaction(
            contract,
            argv.tokenAddress,
            argv.receiver,
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
