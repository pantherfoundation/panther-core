// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('StaticTree');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const tx = await diamond.initializeStaticTree({
        gasPrice: 30000000000,
    });
    const res = await tx.wait();

    const newRoot = await diamond.getStaticRoot();

    console.log(
        `StaticTree is initialized with tx hash ${res.transactionHash}, new static root is ${newRoot}`,
    );
};

export default func;

func.tags = ['init-static-root', 'trees', 'protocol-v1'];
// func.dependencies = [
//     'add-static-tree',
//     'add-blacklisted-zaccount-ids-registry',
//     'add-providers-keys-registry',
//     'add-znetworks-registry',
//     'add-zassets-registry',
//     'add-zzone-registry',
// ];
