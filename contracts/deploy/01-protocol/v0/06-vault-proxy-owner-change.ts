// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts, deployments, ethers} = hre;
    const {deployer} = await getNamedAccounts();
    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    await deployments.fixture['Vault_Proxy'];
    const deployment = await deployments.get('Vault_Proxy');

    const vaultProxy = await ethers.getContractAt(
        deployment.abi,
        deployment.address,
    );

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

func.tags = ['vault-v0-owner', 'pchain', 'protocol-v0'];
func.dependencies = ['check-params', 'vault-v0-upgrade'];
