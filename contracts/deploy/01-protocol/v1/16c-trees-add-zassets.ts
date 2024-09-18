// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;
    const {abi} = await get('ZAssetsRegistryV1');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);
    console.log(`adding zassets to ${diamond.address}`);
};
export default func;

func.tags = ['add-zassets', 'trees', 'protocol-v1'];
func.dependencies = ['add-zassets-registry', 'add-static-tree'];
