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

    const pantherVerifier = await getContractAddress(
        hre,
        'PantherVerifier',
        'PANTHER_VERIFIER',
    );
    const pantherPool = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );

    const zkpToken = getContractEnvAddress(hre, 'ZKP_TOKEN');

    const pointer = getContractEnvAddress(hre, 'VK_PANTHERBUSTREEUPDATER');

    if (pointer) {
        await deploy('MockBusTree', {
            from: deployer,
            args: [pantherPool, zkpToken, pantherVerifier, pointer],
            libraries: {
                PoseidonT3: poseidonT3,
            },
            log: true,
            autoMine: true,
        });
    } else console.log('Undefined pointer, skip BusTree deployment');
};
export default func;

func.tags = ['bus-tree', 'forest', 'protocol'];
func.dependencies = ['crypto-libs', 'verifier', 'add-verification-key'];
