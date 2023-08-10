import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy, get},
        getNamedAccounts,
    } = hre;
    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    await deploy('MockTaxiTree', {
        from: deployer,
        libraries: {
            PoseidonT3: poseidonT3,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['taxi-tree', 'forest', 'protocol'];
func.dependencies = ['crypto-libs'];
