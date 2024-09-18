// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress, getPZkpToken} from '../../lib/deploymentHelpers';

//? Note: This script is supposed to be deleted
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    const pZkp = await getPZkpToken(hre);

    const minerRewards = process.env.MINER_REWARDS as string;
    const data = hre.ethers.utils.defaultAbiCoder.encode(
        ['uint256'],
        [minerRewards],
    );

    const tx = await pZkp.deposit(vaultProxy, data);
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['allocate-miner-rewards', 'protocol'];
func.dependencies = ['check-params', 'pzkp-token', 'vault-proxy'];
