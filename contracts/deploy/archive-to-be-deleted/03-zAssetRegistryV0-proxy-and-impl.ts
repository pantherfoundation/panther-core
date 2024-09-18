// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    getContractEnvAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    //TODO: add protocol-v0 tag to deploy this contract
    return;
    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const constructorArgs = [multisig];

    if (reuseEnvAddress(hre, 'Z_ASSET_REGISTRY_PROXY')) {
        if (reuseEnvAddress(hre, 'Z_ASSET_REGISTRY_IMP')) return;
        else {
            await deploy('ZAssetsRegistry_Implementation', {
                contract: 'ZAssetsRegistry',
                from: deployer,
                args: constructorArgs,
                log: true,
                autoMine: true,
            });

            const zAssetsRegistryProxy = getContractEnvAddress(
                hre,
                'Z_ASSET_REGISTRY_PROXY',
            ) as string;

            const zAssetsRegistryImpl = await hre.ethers.getContract(
                'ZAssetsRegistry_Implementation',
            );

            await upgradeEIP1967Proxy(
                hre,
                deployer,
                zAssetsRegistryProxy,
                zAssetsRegistryImpl.address,
                'zAssetRegistery',
            );
        }
    } else {
        await deploy('ZAssetsRegistry', {
            from: deployer,
            args: constructorArgs,
            proxy: {
                proxyContract: 'EIP173Proxy',
                owner: multisig,
            },
            log: true,
            autoMine: true,
        });
    }
};

export default func;

func.tags = ['z-asset-registry', 'protocol'];
func.dependencies = ['check-params', 'deployment-consent'];
