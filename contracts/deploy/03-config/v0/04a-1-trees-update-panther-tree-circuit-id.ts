// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {createSafeTransaction, saveSafeTransaction} from '../utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('ForestTree');
    const {address} = await get('PantherTrees');
    const diamond = await ethers.getContractAt(abi, address);

    const verificationKeys = JSON.parse(
        process.env.VERIFICATION_KEY_POINTERS as string,
    );

    const pointer = hre.ethers.BigNumber.from(
        verificationKeys.filter((x: any) => x.key === 'busTreeUpdater')[0]
            .pointer,
    );

    const tx =
        await diamond.populateTransaction.updateBusTreeCircuitId(pointer);

    const transaction = createSafeTransaction(address, tx.data!);

    await saveSafeTransaction(hre, transaction, __filename);
};

export default func;

func.tags = ['config', 'config:trees', 'config:update-panther-tree-circuit-id'];
