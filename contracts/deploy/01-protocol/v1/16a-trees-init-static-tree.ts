// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('StaticTree');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const tx = await diamond.initializeStaticTree({
        gasPrice: GAS_PRICE,
    });
    const res = await tx.wait();

    const newRoot = await diamond.getStaticRoot();

    console.log(
        `StaticTree is initialized with tx hash ${res.transactionHash}, new static root is ${newRoot}`,
    );
};

export default func;

func.tags = ['init-static-root', 'trees', 'protocol-v1'];
func.dependencies = [
    'add-static-tree',
    'add-blacklisted-zaccount-ids-registry',
    'add-providers-keys-registry',
    'add-znetworks-registry',
    'add-zassets-registry',
    'add-zzone-registry',
];
