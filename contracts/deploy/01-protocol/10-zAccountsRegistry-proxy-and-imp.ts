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

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const PoseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;

    const PoseidonT4 =
        getContractEnvAddress(hre, 'POSEIDON_T4') ||
        (await get('PoseidonT4')).address;

    const poolV1 = await deploy('MockPantherPoolV1', {
        from: deployer,
        log: true,
        autoMine: true,
    });

    const constructorArgs = [multisig, poolV1.address];

    await deploy('ZAccountsRegistry', {
        from: deployer,
        args: constructorArgs,
        libraries: {
            PoseidonT3,
            PoseidonT4,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['account-registry', 'protocol'];
func.dependencies = ['check-params', 'crypto-libs'];
