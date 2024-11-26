// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE, zkpAmount, prpVirtualAmount} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('PrpConversion');
    const {address} = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(abi, address);

    {
        const pZkp = await ethers.getContractAt('MockPZkp', pzkp);
        console.log('transfering zkp tokens...');
        const tx = await pZkp.transfer(diamond.address, zkpAmount, {
            gasPrice: GAS_PRICE,
        });
        const res = await tx.wait();
        console.log('zkp tokens are transfered', res.transactionHash);
    }

    {
        console.log('initialize prpConversion');
        const tx = await diamond.initPool(prpVirtualAmount, zkpAmount, {
            gasPrice: GAS_PRICE,
        });
        const res = await tx.wait();
        console.log('prpConversion is initializd', res.transactionHash);
    }
};
export default func;

func.tags = ['init-prp-conversion', 'core', 'protocol-v1'];
func.dependencies = ['add-prp-conversion'];
