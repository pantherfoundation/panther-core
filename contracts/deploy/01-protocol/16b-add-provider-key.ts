// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {packPublicKey} from '@panther-core/crypto/lib/base/keypairs';
import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon, eddsa} from 'circomlibjs';
import {fromRpcSig} from 'ethereumjs-util';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // TODO: Fix registration of the trust provider signature
    // as soon as the `ProvidersKeys` gets refactored in this part
    return;

    if (isProd(hre)) return;
    const {artifacts, ethers} = hre;

    const [signer] = await ethers.getSigners();

    const providersKeyAddress = await getContractAddress(
        hre,
        'ProvidersKeys',
        '',
    );

    const {abi} = await artifacts.readArtifact('ProvidersKeys');
    const providersKeys = await ethers.getContractAt(abi, providersKeyAddress);

    const name = await providersKeys.EIP712_NAME();
    const version = await providersKeys.EIP712_VERSION();
    const chainId = (await ethers.provider.getNetwork()).chainId;

    const salt = await providersKeys.EIP712_SALT();
    const verifyingContract = providersKeys.address;
    const providersKeysVersion = await providersKeys.KEYRING_VERSION();

    const prvKey = Buffer.from(
        '0001020304050607080900010203040506070809000102030405060708090001',
        'hex',
    );
    const pubKey = eddsa.prv2pub(prvKey);

    const publicKey = [BigInt(pubKey[0]), BigInt(pubKey[1])] as [
        bigint,
        bigint,
    ];

    const keyringId = '1';
    const pubRootSpendingKey = packPublicKey(publicKey);
    const expiryDate = '1735689600';

    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const kycKytMerkleTree = new MerkleTree(poseidon, 16, zeroValue);

    const kycKytMerkleTreeLeaf = poseidon([
        publicKey[0], // x
        publicKey[1], // y
        1735689600n, // expiry (2025-01-01T00:00:00Z)
    ]);

    kycKytMerkleTree.insert(kycKytMerkleTreeLeaf);

    const proof = kycKytMerkleTree.createProof(0);

    const types = {
        Registration: [
            {name: 'keyringId', type: 'uint32'},
            {name: 'pubRootSpendingKey', type: 'bytes32'},
            {name: 'expiryDate', type: 'uint32'},
            {name: 'version', type: 'uint256'},
        ],
    };

    const value = {
        keyringId,
        pubRootSpendingKey,
        expiryDate,
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
    const {v, r, s} = fromRpcSig(signature); // does nothing other that splitting the signature string

    const tx = await providersKeys.registerKey(
        keyringId,
        {
            x: publicKey[0].toString(),
            y: publicKey[1].toString(),
        },
        expiryDate,
        proof.siblingNodes.map(x => ethers.BigNumber.from(x)._hex),
        v,
        r,
        s,
    );

    const res = await tx.wait();
    console.log('Transaction is confirmed.', res.transactionHash);
};
export default func;

func.tags = ['add-provider-key', 'forest', 'protocol'];
func.dependencies = ['providers-keys', 'add-provider'];
