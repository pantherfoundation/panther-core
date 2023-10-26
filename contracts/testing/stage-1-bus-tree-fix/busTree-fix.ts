// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import fs from 'fs';
import {join as pathJoin} from 'path';

import axios from 'axios';
import {BigNumber} from 'ethers';
import {ethers, network} from 'hardhat';

/**
 * 
Executing command to run the script. it has been assumed that the commands
are executed in the contracts workspace

To execute on Mumbai:
 
  ```  
   yarn hardhat run testing/stage-1-bus-tree-fix/busTree-fix.ts --network mumbai

  ```

To execute on the Forked Mumbai

  ```
  export SIGNER_PK=<Private_KEY> \
  export POLYGON_SCAN_API_KEY=<API_KEY> \
  export HARDHAT_FORKING_ENABLED=1 \
  export HARDHAT_FORKING_BLOCK=<Block> \
  export HARDHAT_FORKING_URL=https://polygon-mumbai.g.alchemy.com/v2/<API> &&
  yarn hardhat run testing/stage-1-bus-tree-fix/busTree-fix.ts 

  ```
 */

const config = {
    // Reading all of the zAccount activation transactions from start block till end block
    readZAccountActivationTransactions: {
        enable: true,
        zAccountsRegistryAddress: '0x994Ce1714D0F25495Ec9600844bC2fcf3a71d238',
        activateZAccountSig: '0x03e52083',
        startBlock: '38977517',
        endBlock: 'latest',
        message: 'Reading ZAccount Activation Transactions',
    },
    // Writing zAccount activation transactions in an json file
    writeZAccountActivationTransactions: {
        enable: false,
        path: './activationTransactions.json',
        message: 'Writing ZAccount Activation Transactions',
    },
    // Executing pool to add correct utxos into BusTree and emit txNote event
    emitTxNoteAndAddUtxos: {
        enable: true,
        pantherPoolAddress: '0x7Caa195a4A580b9bfc66F8aC87B2Eb8008FB89B7',
        message: 'Emitting TxNote and Adding UTXOs',
    },
    // Executing zAccountRegistry to store Nullifiers
    updateZAccountsRegistry: {
        enable: true,
        zAccountsRegistryAddress: '0x994Ce1714D0F25495Ec9600844bC2fcf3a71d238',
        message: 'Updating ZAccounts Registry',
    },
};

async function readZAccountActivationTransactions() {
    const {readZAccountActivationTransactions} = config;
    const {
        zAccountsRegistryAddress,
        activateZAccountSig,
        startBlock,
        endBlock,
        enable,
        message,
    } = readZAccountActivationTransactions;

    if (!enable) return;
    else console.log(message);

    const polygonScanApiKey = process.env.POLYGON_SCAN_API_KEY;

    const _endBlock =
        endBlock === 'latest'
            ? (await ethers.provider.getBlock('latest')).number
            : endBlock;

    const url = `https://api-testnet.polygonscan.com/api?module=account&action=txlist&apikey=${polygonScanApiKey}&startblock=${startBlock}&endblock=${_endBlock}&address=${zAccountsRegistryAddress}`;

    try {
        const {data, status} = await axios.get(url);
        if (status != 200)
            throw new Error(`Thrown on getting data with status ${status}`);

        return data.result.filter(
            el => el.methodId === activateZAccountSig && el.isError === '0',
        );
    } catch (error) {
        console.log(error);
        return;
    }
}

async function writeZAccountActivationTransactions(transactions) {
    const {writeZAccountActivationTransactions} = config;
    const {path, enable, message} = writeZAccountActivationTransactions;

    if (!enable) return;
    else console.log(message);

    const jsonPath = pathJoin(__dirname, path);

    fs.writeFileSync(jsonPath, JSON.stringify(transactions));
}

async function extractDataForOnChainModifications(transactions) {
    const iface = new ethers.utils.Interface([
        'function activateZAccount(uint256[] inputs, bytes privateMessages, tuple(tuple(uint256 x, uint256 y), tuple(uint256[2] x, uint256[2] y), tuple(uint256 x, uint256 y)) proof, uint256 cachedForestRootIndex)',
    ]);

    const results: any[] = [];

    transactions.map(el => {
        const data = iface.decodeFunctionData('activateZAccount', el.input);

        const blockNumber = el.blockNumber;
        const privateMessage = data.privateMessages;
        const zAccountId = data.inputs[3];
        const createTime = data.inputs[5];

        // This value has been passed as nullifier to the zAcc registry
        const commitment = data.inputs[9];
        // This value has been passed as commitment to the zAcc registry
        const nullifier = data.inputs[10];

        results.push({
            blockNumber,
            zAccountId,
            createTime,
            commitment,
            nullifier,
            privateMessage,
        });
    });

    return results;
}

async function emitTxNoteAndAddUtxos(
    data: {
        blockNumber: string;
        zAccountId: BigNumber;
        createTime: BigNumber;
        commitment: BigNumber;
        nullifier: BigNumber;
        privateMessage: string;
    }[],
) {
    const {emitTxNoteAndAddUtxos} = config;
    const {pantherPoolAddress, enable, message} = emitTxNoteAndAddUtxos;

    if (!enable) return;
    else console.log(message);

    const signerPk = process.env.SIGNER_PK;
    if (!signerPk) throw new Error('undefined private key env');

    const pantherPool = new ethers.Contract(
        pantherPoolAddress,
        pantherPoolAbi,
        ethers.provider,
    );

    const signer = new ethers.Wallet(signerPk, ethers.provider);

    const createTimes = data.map(el => el.createTime);
    const commitments = data.map(el => el.commitment.toString());
    const privateMessages = data.map(el => el.privateMessage);

    const tx = await pantherPool
        .connect(signer)
        .tempAddZAccountsUtxos(createTimes, commitments, privateMessages);

    const res = await tx.wait();
    console.log('Transaction confirmed', res.transactionHash);
}

async function updateZAccountsRegistry(
    data: {
        blockNumber: string;
        zAccountId: BigNumber;
        createTime: BigNumber;
        commitment: BigNumber;
        nullifier: BigNumber;
        privateMessage: string;
    }[],
) {
    const {updateZAccountsRegistry} = config;
    const {zAccountsRegistryAddress, enable, message} = updateZAccountsRegistry;

    if (!enable) return;
    else console.log(message);

    const signerPk = process.env.SIGNER_PK;
    if (!signerPk) throw new Error('undefined private key env');

    const zAccRegistry = new ethers.Contract(
        zAccountsRegistryAddress,
        zAccountsRegistryAbi,
        ethers.provider,
    );

    const signer = new ethers.Wallet(signerPk, ethers.provider);

    const blockNums = data.map(el => el.blockNumber);
    const nullifiers = data.map(el => el.nullifier);
    const zAccountIds = data.map(el => el.zAccountId);

    const tx = await zAccRegistry
        .connect(signer)
        .tempFixNullifiers(blockNums, nullifiers, zAccountIds);

    const res = await tx.wait();
    console.log('Transaction confirmed', res.transactionHash);
}

async function main() {
    const blockNumber = (await ethers.provider.getBlock('latest')).number;
    console.log(
        `Executing the command on ${network.name} at block ${blockNumber}`,
    );
    const transactions = await readZAccountActivationTransactions();
    writeZAccountActivationTransactions(transactions);
    const data: any = await extractDataForOnChainModifications(transactions);

    await emitTxNoteAndAddUtxos(data);
    await updateZAccountsRegistry(data);
}

main()
    .then(() => console.log('Done'))
    .catch(e => console.log('Unexpected error', e));

// *** ABIs ***

const zAccountsRegistryAbi = [
    {
        inputs: [
            {
                internalType: 'uint256[]',
                name: 'blockNums',
                type: 'uint256[]',
            },
            {
                internalType: 'uint256[]',
                name: 'zAccountNullifiers',
                type: 'uint256[]',
            },
            {
                internalType: 'uint256[]',
                name: 'zAccountIds',
                type: 'uint256[]',
            },
        ],
        name: 'tempFixNullifiers',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
];

const pantherPoolAbi = [
    {
        inputs: [
            {
                internalType: 'uint256[]',
                name: 'createTimes',
                type: 'uint256[]',
            },
            {
                internalType: 'uint256[]',
                name: 'commitments',
                type: 'uint256[]',
            },
            {
                internalType: 'bytes[]',
                name: 'privateMessages',
                type: 'bytes[]',
            },
        ],
        name: 'tempAddZAccountsUtxos',
        outputs: [],
        stateMutability: 'nonpayable',
        type: 'function',
    },
];
