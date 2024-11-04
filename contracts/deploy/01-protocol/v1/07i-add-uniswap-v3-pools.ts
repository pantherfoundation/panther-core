// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pZkp = await getNamedAccount(hre, 'pzkp');
    const link = await getNamedAccount(hre, 'link');
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

    const nativeAddress = ethers.constants.AddressZero; // zero address for native token

    console.log('adding pzkp-native...');
    let tx = await feeMaster.updatePool(
        pZkpNativePool,
        pZkp,
        nativeAddress,
        true,
        {
            gasPrice: 30000000000,
        },
    );
    let res = await tx.wait();
    console.log('pzkp-native is added!', res.transactionHash);

    console.log('adding pzkp-link...');
    tx = await feeMaster.updatePool(pZkpLinkPool, pZkp, link, {
        gasPrice: 30000000000,
    });
    res = await tx.wait();
    console.log('pzkp-link is added!', res.transactionHash);

    console.log('adding link-native...');
    tx = await feeMaster.updatePool(linkNativePool, link, nativeAddress, {
        gasPrice: 30000000000,
    });
    res = await tx.wait();
    console.log('link-native is added!', res.transactionHash);
};

export default func;

func.tags = ['add-uniswap-v3-pool', 'core', 'protocol-v1'];
func.dependencies = ['fee-master'];
