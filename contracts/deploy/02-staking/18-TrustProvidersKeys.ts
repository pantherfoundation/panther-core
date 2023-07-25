import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractEnvAddress,
    reuseEnvAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {deployments, getNamedAccounts} = hre;
    const {deploy, get} = deployments;
    const {deployer} = await getNamedAccounts();

    await verifyUserConsentOnProd(hre, deployer);
    if (reuseEnvAddress(hre, 'TrustProvidersKeys')) return;

    const poseidonT3 =
        getContractEnvAddress(hre, 'POSEIDON_T3') ||
        (await get('PoseidonT3')).address;
    const poseidonT4 =
        getContractEnvAddress(hre, 'POSEIDON_T4') ||
        (await get('PoseidonT4')).address;

    const libraries = {
        PoseidonT3: poseidonT3,
        PoseidonT4: poseidonT4,
    };

    let owner: string;

    if (isProd(hre))
        owner =
            process.env.DAO_MULTISIG_ADDRESS ||
            (await getNamedAccounts()).multisig;
    else owner = deployer;

    await deploy('TrustProvidersKeys', {
        from: deployer,
        args: [owner],
        libraries,
        log: true,
        autoMine: true,
    });
};
export default func;

func.tags = ['advanced-staking', 'trust-provider-key'];
func.dependencies = ['check-params'];
