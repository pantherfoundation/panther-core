// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress, getPZkpToken} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {artifacts, ethers} = hre;

    await verifyUserConsentOnProd(hre, deployer);

    const zAssetRegistryAddress = await getContractAddress(
        hre,
        'ZAssetsRegistryV1',
        '',
    );

    const {abi} = await artifacts.readArtifact('ZAssetsRegistryV1');
    const zAssetRegistry = await ethers.getContractAt(
        abi,
        zAssetRegistryAddress,
    );

    const pZkp = await getPZkpToken(hre);

    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const merkleTree = new MerkleTree(poseidon, 16, zeroValue);
    const curRoot = ethers.BigNumber.from(merkleTree.root)._hex;

    const leaf0 = ethers.BigNumber.from(
        poseidon([0, BigInt(pZkp.address), 0, 1, 0, 20, 1e12]),
    )._hex;

    merkleTree.insert(leaf0);
    const proof = merkleTree.createProof(0);

    const proofSiblings = proof.siblingNodes.map(
        x => ethers.BigNumber.from(x)._hex,
    );

    const tx = await zAssetRegistry.addZAsset(
        curRoot,
        zeroValue,
        leaf0,
        0,
        proofSiblings,
    );

    const newRoot = await zAssetRegistry.getRoot();

    await tx.wait();

    console.log(
        `pZkp token is added to zAssetsRegistry. new zAsset tree root is ${newRoot}`,
    );
};
export default func;

func.tags = ['z-assets-registry', 'forest', 'protocol'];
