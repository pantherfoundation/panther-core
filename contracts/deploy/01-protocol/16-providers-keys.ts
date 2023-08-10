import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    getContractAddress,
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

    const poseidonT4 =
        getContractEnvAddress(hre, 'POSEIDON_T4') ||
        (await get('PoseidonT4')).address;

    const staticTree = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );
    const babyJubJub = await getContractAddress(hre, 'BabyJubJub', '');

    await deploy('ProvidersKeys', {
        from: deployer,
        args: [deployer, 1, staticTree],
        libraries: {
            PoseidonT3: poseidonT3,
            PoseidonT4: poseidonT4,
            BabyJubJub: babyJubJub,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['providers-keys', 'forest', 'protocol'];
func.dependencies = ['crypto-libs'];
