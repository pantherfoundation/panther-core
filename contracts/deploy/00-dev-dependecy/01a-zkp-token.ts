import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    abi,
    bytecode,
} from '../../deployments/ARCHIVE/externalAbis/ZKPToken.json';
import {isProd} from '../../lib/checkNetwork';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();

    await deploy('Zkp_token', {
        contract: {
            abi,
            bytecode,
        },
        from: deployer,
        args: [deployer],
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['zkp-imp', 'dev-dependency'];
