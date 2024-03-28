// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {BigNumberish} from '@ethersproject/bignumber/src.ts';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {poseidon2or3} from '@panther-core/crypto/lib/base/hashes';
import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import {fromRpcSig} from 'ethereumjs-util';
import {ethers} from 'hardhat';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

import {ProvidersKeys, G1PointStruct} from '../types/contracts/ProvidersKeys';

export async function genSignatureForRegisterProviderKey(
    hre: HardhatRuntimeEnvironment,
    providersKeys: ProvidersKeys,
    keyringId: string,
    pubRootSpendingKey: G1PointStruct,
    expiryDate: string,
    proofSiblings: string[],
    signer: SignerWithAddress,
): Promise<{
    v: number;
    r: Buffer;
    s: Buffer;
}> {
    const name = await providersKeys.EIP712_NAME();
    const version = await providersKeys.EIP712_VERSION();
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;

    const salt = await providersKeys.EIP712_SALT();
    const verifyingContract = providersKeys.address;
    const providersKeysVersion = await providersKeys.KEYRING_VERSION();

    const types = {
        RegisterKey: [
            {name: 'keyringId', type: 'uint16'},
            {name: 'pubRootSpendingKey', type: 'G1Point'},
            {name: 'expiryDate', type: 'uint32'},
            {name: 'proofSiblings', type: 'bytes32[]'},
            {name: 'version', type: 'uint256'},
        ],
        G1Point: [
            {name: 'x', type: 'uint256'},
            {name: 'y', type: 'uint256'},
        ],
    };

    const value = {
        keyringId,
        pubRootSpendingKey,
        expiryDate,
        proofSiblings,
        version: providersKeysVersion,
    };

    const domain: TypedDataDomain = {
        name,
        version,
        chainId,
        verifyingContract,
        salt,
    };

    const signature = await signer._signTypedData(domain, types, value);
    return fromRpcSig(signature); // does nothing other that splitting the signature string
}

function generateleaf(): BigNumberish {
    const leaf = ethers.BigNumber.from(
        ethers.utils.formatBytes32String('random-leaf'),
    ).mod(SNARK_FIELD_SIZE)._hex;
    return leaf;
}

export function generateProof(leafIndex: number): Bytes[] {
    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const merkleTree = new MerkleTree(poseidon, 16, zeroValue);
    const leaf = generateleaf();
    merkleTree.insert(leaf);

    const proof = merkleTree.createProof(leafIndex);

    return proof.siblingNodes.map(x => ethers.BigNumber.from(x)._hex);
}

export function getKeyCommitment(
    key: G1PointStruct,
    expiryDate: bigint,
): BigNumberish {
    const commitment = poseidon2or3([key.x, key.y, expiryDate]);
    return commitment;
}

export function calcNewRoot(
    curRoot: BigNumberish,
    leaf: BigNumberish,
    newLeaf: BigNumberish,
    leafIndex: number,
    proofSiblings: BigNumberish[],
): BigNumberish {
    if (newLeaf === leaf) {
        throw new Error('BIUT: New leaf cannot be equal to the old one');
    }

    let _newRoot: any = newLeaf;
    let proofPathIndice: number;

    for (let i = 0; i < proofSiblings.length; i++) {
        proofPathIndice = (leafIndex >> i) & 1;

        if (proofPathIndice === 0) {
            _newRoot = poseidon2or3([_newRoot, proofSiblings[i]]);
        } else {
            _newRoot = poseidon2or3([proofSiblings[i], _newRoot]);
        }
    }

    return _newRoot;
}
