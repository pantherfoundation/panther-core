// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

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
        (x: any) => x.key === 'oneInputPoseidonHasher',
    )[0].pointer;

    const reservationRate = '2000';
    const premiumRate = '10';
    const minEmptyQueueAge = '100';

    const tx = await diamond.initializeForestTrees(
        pointer,
        reservationRate,
        premiumRate,
        minEmptyQueueAge,
        {
            gasPrice: 30000000000,
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
