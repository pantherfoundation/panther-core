// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');
    const weth9 = await getNamedAccount(hre, 'weth9');
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {deploy, get},
        ethers,
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;
    const treesDiamond = (await get('PantherTrees')).address;
    const vaultV1 = (await get('VaultV1')).address;
    const paymaster = (await get('Paymaster_Proxy')).address;
    const pantherTreasury = (await get('Treasury')).address;
    const trustProvider = (await get('ComplianceTreasury')).address;

    const providers = {
        pantherPool: coreDiamond,
        pantherTrees: treesDiamond,
        paymaster,
        trustProvider,
    };

    const feeMasterImpl = await deploy('FeeMaster_Implementation', {
        contract: 'FeeMaster',
        from: deployer,
        args: [multisig, providers, pzkp, weth9, vaultV1, pantherTreasury],
        log: true,
        autoMine: true,
        gasPrice: GAS_PRICE,
    });

    const feeMasterProxy = await get('FeeMaster');
    const proxy = await ethers.getContractAt(
        'EIP173ProxyWithReceive',
        feeMasterProxy.address,
    );

    const tx = await proxy.upgradeTo(feeMasterImpl.address, {
        gasPrice: GAS_PRICE,
    });
    await tx.wait();

    const currentOwner = await proxy.owner();
    if (currentOwner !== multisig) {
        const tx = await proxy.transferOwnership(multisig, {
            gasPrice: GAS_PRICE,
        });
        await tx.wait();
    }
};
export default func;

func.tags = ['fee-master', 'core', 'protocol-v1', 'protocol-v1-deploy'];
func.dependencies = [
    'core-diamond',
    'trees-diamond',
    'paymaster-proxy',
    'vault-v1',
    'treasury-proxy',
    'compliance-treasury',
];
