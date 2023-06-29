import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {
    reuseEnvAddress,
    getContractAddress,
    getContractEnvAddress,
    verifyUserConsentOnProd,
    upgradeEIP1967Proxy,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {deploy},
        getNamedAccounts,
    } = hre;

    const {deployer} = await getNamedAccounts();
    await verifyUserConsentOnProd(hre, deployer);

    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const vaultProxy = await getContractAddress(
        hre,
        'Vault_Proxy',
        'VAULT_PROXY',
    );

    if (reuseEnvAddress(hre, 'PANTHER_POOL_V1_PROXY')) {
        if (reuseEnvAddress(hre, 'PANTHER_POOL_V1_IMP')) return;
        else {
            await deploy('PantherPoolV1_Implementation', {
                contract: 'MockPantherPoolV1',
                from: deployer,
                args: [vaultProxy, multisig],
                log: true,
                autoMine: true,
            });

            const pantherPoolV1Proxy = getContractEnvAddress(
                hre,
                'PANTHER_POOL_V1_PROXY',
            ) as string;

            const pantherPoolV1Impl = await hre.ethers.getContract(
                'PantherPoolV1_Implementation',
            );

            await upgradeEIP1967Proxy(
                hre,
                deployer,
                pantherPoolV1Proxy,
                pantherPoolV1Impl.address,
                'pantherPool',
            );
        }
    } else {
        await deploy('PantherPoolV1', {
            contract: 'MockPantherPoolV1',
            from: deployer,
            args: [vaultProxy, multisig],
            proxy: {
                proxyContract: 'EIP173Proxy',
                owner: multisig,
            },
            log: true,
            autoMine: true,
        });
    }
};

export default func;

func.tags = ['pool-v1', 'protocol'];
func.dependencies = ['check-params', 'vault-proxy'];
