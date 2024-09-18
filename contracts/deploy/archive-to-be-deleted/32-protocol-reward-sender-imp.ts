// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getContractEnvAddress,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const prpConverterProxy = '0xf93af6d5DB557BD7aEA1fe19276b93AF6D28b36F';
    const protocolRewardMessageRelayer =
        '0x22B9e399B3A413F9bc48821b38969647C5DA3Cad';
    const protocolRewardController = await getContractAddress(
        hre,
        'ProtocolRewardController_Proxy',
        'ProtocolRewardController_Proxy',
    );
    const zkp = '0x9a27804316F7b31110E3823b68578A821D144bA0';

    const rootChainManagerProxy = await getContractAddress(
        hre,
        'MockRootChainManager_Proxy',
        '',
    );
    const erc20PredicateProxy = await getContractAddress(
        hre,
        'MockRootChainManager_Proxy',
        '',
    );
    const fxRoot = getContractEnvAddress(hre, 'FX_ROOT');

    console.log({
        multisig,
        prpConverterProxy,
        protocolRewardMessageRelayer,
        protocolRewardController,
        zkp,
        rootChainManagerProxy,
        erc20PredicateProxy,
        fxRoot,
    });

    await deploy('ToPolygonZkpTokenAndPrpRewardMsgSender_Implementation', {
        contract: 'ToPolygonZkpTokenAndPrpRewardMsgSender',
        from: deployer,
        args: [
            multisig,
            prpConverterProxy,
            protocolRewardMessageRelayer,
            protocolRewardController,
            zkp,
            rootChainManagerProxy,
            erc20PredicateProxy,
            fxRoot,
        ],

        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['protocol-reward-sender-imp', 'protocol'];
func.dependencies = [
    'check-params',
    'deployment-consent',
    'protocol-reward-relayer',
    'protocol-reward-ctrl',
    'protocol-token',
];
