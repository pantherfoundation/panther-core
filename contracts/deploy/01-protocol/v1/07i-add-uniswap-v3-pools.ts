// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pZkp = await getNamedAccount(hre, 'pzkp');
    const link = await getNamedAccount(hre, 'link');
    const weth9 = await getNamedAccount(hre, 'weth9');
    const pZkpNativePool = await getNamedAccount(hre, 'pZkp_native_pool');
    const pZkpLinkPool = await getNamedAccount(hre, 'link_native_pool');
    const linkNativePool = await getNamedAccount(hre, 'link_native_pool');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    console.log('adding pzkp-native...');
    let tx = await feeMaster.addPool(pZkpNativePool, pZkp, weth9, {
        gasPrice: 30000000000,
    });
    let res = await tx.wait();
    console.log('pzkp-native is added!', res.transactionHash);

    console.log('adding pzkp-link...');
    tx = await feeMaster.addPool(pZkpLinkPool, pZkp, link, {
        gasPrice: 30000000000,
    });
    res = await tx.wait();
    console.log('pzkp-link is added!', res.transactionHash);

    console.log('adding link-native...');
    tx = await feeMaster.addPool(linkNativePool, link, weth9, {
        gasPrice: 30000000000,
    });
    res = await tx.wait();
    console.log('link-native is added!', res.transactionHash);
};

export default func;

func.tags = ['add-uniswap-v3-pool', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
