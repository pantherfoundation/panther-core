import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        ethers,
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'MOCK_BUS_TREE_PROXY')) return;

    await deploy('PantherBusTree_Proxy', {
        contract: 'EIP173Proxy',
        from: deployer,
        args: [
            ethers.constants.AddressZero, // implementation will be changed
            deployer, // owner will be changed
            [], // data
        ],
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['bus-tree-proxy', 'forest', 'protocol'];
func.dependencies = ['check-params'];
