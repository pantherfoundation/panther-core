import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'ORC')) return;

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    await deploy('OnboardingController', {
        from: deployer,
        args: [multisig, multisig, multisig, multisig, multisig],
        proxy: {
            proxyContract: 'EIP173Proxy',
            owner: multisig,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['onboarding-reward-ctrl', 'protocol'];
func.dependencies = ['check-params'];
