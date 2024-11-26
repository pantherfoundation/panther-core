// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE, FOREST_TREE} from './parameters';

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

    const pointer = verificationKeys.filter(
        (x: any) => x.key === 'busTreeUpdater',
    )[0].pointer;

    const tx = await diamond.initializeForestTrees(
        pointer,
        FOREST_TREE.reservationRate,
        FOREST_TREE.premiumRate,
        FOREST_TREE.minEmptyQueueAge,
        {
            gasPrice: GAS_PRICE,
        },
    );
    const res = await tx.wait();

    const {_forestRoot} = await diamond.getRoots();

    console.log(
        `ForestTree is initialized with tx hash ${res.transactionHash}, new forest root is ${_forestRoot}`,
    );
};

export default func;

func.tags = ['init-forest-root', 'trees', 'protocol-v1'];
func.dependencies = ['add-forest-tree', 'verifications-keys'];
