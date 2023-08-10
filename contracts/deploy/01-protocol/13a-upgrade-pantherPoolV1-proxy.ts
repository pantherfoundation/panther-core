import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const pantherPoolV1Proxy = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );
    const pantherPoolV1Impl = await getContractAddress(
        hre,
        'PantherPoolV1_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        pantherPoolV1Proxy,
        pantherPoolV1Impl,
        'pool v1',
    );
};

export default func;

func.tags = ['pool-v1-upgrade', 'protocol'];
func.dependencies = ['check-params'];
