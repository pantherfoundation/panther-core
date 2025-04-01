// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pZkp = await getNamedAccount(hre, 'pzkp');
    const link = await getNamedAccount(hre, 'link');
    const weth9 = await getNamedAccount(hre, 'weth9');
    const pZkpNativePool = await getNamedAccount(
        hre,
        'pZkp_native_uniswapV3Pool',
    );
    const pZkpLinkPool = await getNamedAccount(hre, 'pZkp_link_uniswapV3Pool');
    const linkNativePool = await getNamedAccount(
        hre,
        'link_native_uniswapV3Pool',
    );

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    console.log('adding pzkp-native...');
    let tx = await feeMaster.updatePool(pZkpNativePool, weth9, pZkp, true, {
        gasPrice: GAS_PRICE,
    });
    let res = await tx.wait();
    console.log('pzkp-native is added!', res.transactionHash);

    console.log('adding pzkp-link...');
    tx = await feeMaster.updatePool(pZkpLinkPool, link, pZkp, {
        gasPrice: GAS_PRICE,
    });
    res = await tx.wait();
    console.log('pzkp-link is added!', res.transactionHash);

    console.log('adding link-native...');
    tx = await feeMaster.updatePool(linkNativePool, weth9, link, {
        gasPrice: GAS_PRICE,
    });
    res = await tx.wait();
    console.log('link-native is added!', res.transactionHash);
};

export default func;

func.tags = ['add-uniswap-v3-pool', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
