import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {verifyUserConsentOnProd} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);

    await deploy('ZNetworksRegistry', {
        from: deployer,
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['z-networks-registry', 'forest', 'protocol'];
func.dependencies = ['crypto-libs'];
