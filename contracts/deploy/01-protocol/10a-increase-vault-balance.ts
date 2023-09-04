// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

// TODO To be deleted after adding `onboardingRewardController` contract
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;
    const {deployer} = await getNamedAccounts();

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    const zkpToken = getContractEnvAddress(hre, 'ZKP_TOKEN');
    const {abi} = await artifacts.readArtifact('TokenMock');

    const token = await ethers.getContractAt(abi, zkpToken);

    const vaultBalance = process.env['VAULT_BALANCE'];
    const deployerBalance = await token.balanceOf(deployer);

    if (ethers.BigNumber.from(vaultBalance).lte(deployerBalance)) {
        console.log(
            'Increasing vault balance by',
            ethers.utils.formatEther(vaultBalance),
        );

        const tx = await token.transfer(vaultProxy, vaultBalance);
        const res = await tx.wait();

        console.log('Transaction confirmed', res.transactionHash);
    } else {
        console.log(
            'Skipping increase of the vault balance due to lack of deployer ZKP balance.',
        );
    }
};

export default func;

func.tags = ['inc-vault-balance', 'protocol'];
func.dependencies = ['check-params', 'vault-proxy'];
