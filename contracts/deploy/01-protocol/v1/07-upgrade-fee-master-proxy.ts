// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const feeMasterImpl = await get('FeeMaster_Implementation');
    const feeMasterProxy = await get('FeeMaster_Proxy');

    const proxy = await ethers.getContractAt(
        'EIP173ProxyWithReceive',
        feeMasterProxy.address,
    );

    const tx = await proxy.upgradeTo(feeMasterImpl.address, {
        gasPrice: GAS_PRICE,
    });
    await tx.wait();
};
export default func;

func.tags = ['upgrade-fee-master', 'core', 'protocol-v1', 'protocol-v1-deploy'];
func.dependencies = ['fee-master-proxy-only', 'fee-master-impl'];
