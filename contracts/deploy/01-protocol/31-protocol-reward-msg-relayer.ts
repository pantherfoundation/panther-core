// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    getContractEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);

    const polygonRewardSender = '0xfffD2E141581006eA0c1e91bd5D109A8a72C71C8';
    const fxChild = getContractEnvAddress(hre, 'FX_CHILD');
    const prpVoucherGrantor = await getContractAddress(
        hre,
        'PrpVoucherGrantor_Proxy',
        '',
    );
    const prpConverter = await getContractAddress(
        hre,
        'PrpConverter_Proxy',
        '',
    );

    await deploy('PolygonPrpRewardMsgRelayer', {
        from: deployer,
        args: [polygonRewardSender, fxChild, prpVoucherGrantor, prpConverter],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: deployer,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['protocol-reward-relayer', 'protocol'];
func.dependencies = ['check-params', 'prp-voucher-grantor', 'prp-converter'];
