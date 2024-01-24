// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getNamedAccount} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {ethers} = hre;

    const deployer = await getNamedAccount(hre, 'deployer');
    const multisig = await getNamedAccount(hre, 'multisig');

    const vaultProxy = await ethers.getContract('Vault_Proxy');

    const oldOwner = await vaultProxy.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(`Vault_Proxy owner is already set to: ${multisig}`);
    } else {
        console.log(`Transferring ownership of Vault_Proxy to ${multisig}...`);

        const signer = await ethers.getSigner(deployer);
        const tx = await vaultProxy.connect(signer).transferOwnership(multisig);

        console.log('Vault_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['vault-owner', 'pchain', 'protocol'];
func.dependencies = ['check-params', 'vault-upgrade'];
