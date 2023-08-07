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

    const poseidonT6 =
        getContractEnvAddress(hre, 'POSEIDON_T6') ||
        (await get('PoseidonT6')).address;

    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const zAssetsRegistryV1 = await getContractAddress(
        hre,
        'ZAssetsRegistryV1',
        '',
    );
    const zZonesRegistry = await getContractAddress(hre, 'ZZonesRegistry', '');
    const providersKeys = await getContractAddress(hre, 'ProvidersKeys', '');
    const zAccountsRegistry = await getContractAddress(
        hre,
        'ZAccountsRegistry',
        '',
    );
    const zNetworksRegistry = await getContractAddress(
        hre,
        'ZNetworksRegistry',
        '',
    );

    await deploy('PantherStaticTree_Implementation', {
        contract: 'PantherStaticTree',
        from: deployer,
        args: [
            deployer,
            pantherPool,
            zAssetsRegistryV1,
            zAccountsRegistry,
            zNetworksRegistry,
            zZonesRegistry,
            providersKeys,
        ],
        libraries: {
            PoseidonT6: poseidonT6,
        },
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['static-tree-imp', 'forest', 'protocol'];
// func.dependencies = [
//     'crypto-libs',
//     'pool-v1',
//     'verifier',
//     'add-verification-key',
// ];
