import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {getNamedAccounts} = hre;
    const {deployer} = await getNamedAccounts();

    const MockFxPortalProxy = await getContractAddress(
        hre,
        'MockFxPortal_Proxy',
        '',
    );
    const MockFxPortalImp = await getContractAddress(
        hre,
        'MockFxPortal_Implementation',
        '',
    );

    await upgradeEIP1967Proxy(
        hre,
        deployer,
        MockFxPortalProxy,
        MockFxPortalImp,
        'MockFxPortal',
    );
};

export default func;

func.tags = ['fx-portal', 'fx-portal-proxy-upgrade', 'dev-dependency'];
func.dependencies = ['fx-portal-proxy', 'fx-portal-imp'];
