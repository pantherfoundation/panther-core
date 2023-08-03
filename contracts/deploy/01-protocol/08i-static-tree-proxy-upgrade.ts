import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const staticTreeProxy = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );
    const staticTreeImpl = await getContractAddress(
        hre,
        'PantherStaticTree_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        staticTreeProxy,
        staticTreeImpl,
        'static tree',
    );
};

export default func;

func.tags = ['static-tree-upgrade', 'protocol'];
