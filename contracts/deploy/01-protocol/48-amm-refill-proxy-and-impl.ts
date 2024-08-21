// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    attemptVerify,
    getContractAddress,
    getNamedAccount,
    reuseEnvAddress,
    upgradeEIP1967Proxy,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy},
        ethers,
    } = hre;

    await verifyUserConsentOnProd(hre, deployer);

    if (reuseEnvAddress(hre, 'AMM_REFILL_PROXY')) return;

    const {ammRefillProxyAddr} = await deploy('AMMRefill_Proxy', {
        contract: 'EIP173Proxy',
        from: deployer,
        args: [
            ethers.constants.AddressZero, // implementation will be changed
            deployer,
            [], // data
        ],
        log: true,
        autoMine: true,
    });

    await attemptVerify(hre, 'EIP173Proxy', ammRefillProxyAddr);

    if (reuseEnvAddress(hre, 'AMM_REFILL_IMPL')) return;

    // Assume AMM is Vault
    const amm = await getContractAddress(hre, 'Vault_Proxy', 'VAULT_PROXY');

    const {ammRefillImplAddr} = await deploy('AMMRefill_Implementation', {
        contract: 'AMMRefill',
        from: deployer,
        args: [pZkp.address, amm, prpVoucherGrantor, 1, 1000, deployer.address],
        log: true,
        autoMine: true,
    });

    await attemptVerify(hre, 'AMMRefill', ammRefillImplAddr);

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        ammRefillProxyAddr,
        ammRefillImplAddr,
        'AMM_REFILL',
    );
};
export default func;

func.tags = ['amm-refill-proxy-and-impl'];
func.dependencies = ['check-params', 'deployment-consent'];
