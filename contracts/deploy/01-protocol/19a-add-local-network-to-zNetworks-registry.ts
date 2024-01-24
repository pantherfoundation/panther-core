// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {MerkleTree} from '@zk-kit/merkle-tree';
import {poseidon} from 'circomlibjs';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;
    const {artifacts, ethers} = hre;

    const zNetworkRegistryAddress = await getContractAddress(
        hre,
        'ZNetworksRegistry',
        '',
    );

    const {abi} = await artifacts.readArtifact('ZNetworksRegistry');
    const zNetworkRegistry = await ethers.getContractAt(
        abi,
        zNetworkRegistryAddress,
    );

    const zeroValue =
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d';
    const merkleTree = new MerkleTree(poseidon, 6, zeroValue);
    const curRoot = ethers.BigNumber.from(merkleTree.root)._hex;

    const leaf0 = ethers.BigNumber.from(
        poseidon([
            1,
            BigInt((await hre.ethers.provider.getNetwork()).chainId),
            1,
            1, // 1 network is enabled
            10,
            1828,
            57646075,
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ]),
    )._hex;

    merkleTree.insert(leaf0);

    const proof = merkleTree.createProof(0);

    const proofSiblings = proof.siblingNodes.map(
        x => ethers.BigNumber.from(x)._hex,
    );

    const tx = await zNetworkRegistry.addNetwork(
        curRoot,
        zeroValue,
        leaf0,
        0,
        proofSiblings,
    );

    const newRoot = await zNetworkRegistry.getRoot();

    await tx.wait();

    console.log(
        `Local network id is added to zNetworkRegistry. new zNetwork tree root is ${newRoot}`,
    );
};
export default func;

func.tags = ['add-network-id', 'forest', 'protocol'];
func.dependencies = ['z-networks-registry'];
