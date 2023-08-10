import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const vaultProxy = await getContractAddress(
        hre,
        'PantherBusTree_Proxy',
        '',
    );
    const vaultImpl = await getContractAddress(
        hre,
        'PantherBusTree_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        vaultProxy,
        vaultImpl,
        'mock bus tree',
    );
};

export default func;

func.tags = ['bus-tree-upgrade', 'protocol'];
func.dependencies = ['check-params', 'bus-tree-impl'];
