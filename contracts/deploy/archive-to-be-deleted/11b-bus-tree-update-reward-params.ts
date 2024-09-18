// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {BigNumberish} from '@ethersproject/bignumber/lib/bignumber';
import {BigNumber, Contract} from 'ethers';
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

type PantherBusTreeParams = {
    perMinuteUtxosLimit: BigNumberish;
    basePerUtxoReward: BigNumberish;
    reservationRate: BigNumberish;
    premiumRate: BigNumberish;
    minEmptyQueueAge: BigNumberish;
};

async function mismatchParams(
    newParams: PantherBusTreeParams,
    busTree: Contract,
) {
    const currentParams: PantherBusTreeParams = {} as PantherBusTreeParams;

    currentParams.perMinuteUtxosLimit = await busTree.perMinuteUtxosLimit();
    currentParams.basePerUtxoReward = await busTree.basePerUtxoReward();

    const queueParams = await busTree.getParams();

    currentParams.reservationRate = queueParams.reservationRate;
    currentParams.premiumRate = queueParams.premiumRate;
    currentParams.minEmptyQueueAge = queueParams.minEmptyQueueAge;

    let mismatch = false;
    for (const param in newParams) {
        if (BigNumber.from(newParams[param]).eq(currentParams[param])) continue;
        else {
            mismatch = true;
            break;
        }
    }

    return mismatch;
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const busTreeAddress = await getContractAddress(
        hre,
        'PantherBusTree_Proxy',
        'MOCK_BUS_TREE_PROXY',
    );

    const {abi} = await artifacts.readArtifact('PantherBusTree');
    const busTree = await ethers.getContractAt(abi, busTreeAddress);

    const pantherBusTreeParams: PantherBusTreeParams = {
        perMinuteUtxosLimit: 13,
        basePerUtxoReward: ethers.utils.parseUnits('1', 17),
        reservationRate: '2000',
        premiumRate: '10',
        minEmptyQueueAge: '100',
    };

    if (await mismatchParams(pantherBusTreeParams, busTree)) {
        console.log(
            'Updating reward params for bus tree',
            pantherBusTreeParams,
        );

        const {
            perMinuteUtxosLimit,
            basePerUtxoReward,
            reservationRate,
            premiumRate,
            minEmptyQueueAge,
        } = pantherBusTreeParams;

        const tx = await busTree.updateParams(
            perMinuteUtxosLimit,
            basePerUtxoReward,
            reservationRate,
            premiumRate,
            minEmptyQueueAge,
        );

        const res = await tx.wait();

        console.log('Transaction confirmed', res.transactionHash);
    }
};
export default func;

func.tags = ['bus-tree-update-params', 'forest', 'protocol'];
func.dependencies = ['bus-tree'];
