// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const ADDRESS_ONE = '0x0000000000000000000000000000000000000001';
const BYTES_ONE = '0x00000001';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
    } = hre;

    const coreDiamond = (await deployments.get('PantherPoolV1')).address;

    const poolMainSelector = ethers.utils
        .id(
            'main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint8,uint96,bytes)',
        )
        .slice(0, 10);

    const activateZAccountSelector = ethers.utils
        .id(
            'activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
        )
        .slice(0, 10);

    const claimRewardsSelector = ethers.utils
        .id(
            'claimRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
        )
        .slice(0, 10);

    const convertSelector = ethers.utils
        .id(
            'convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)',
        )
        .slice(0, 10);

    const swapZAssetSelector = ethers.utils
        .id(
            'swapZAsset(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes,bytes)',
        )
        .slice(0, 10);

    await deploy('Account', {
        from: deployer,
        args: [
            [
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
            ],
            [
                poolMainSelector,
                activateZAccountSelector,
                claimRewardsSelector,
                convertSelector,
                swapZAssetSelector,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
            ],
            [356, 324, 324, 356, 324, 0, 0, 0],
        ],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['account'];
func.dependencies = ['core-diamond'];
