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
        artifacts,
        ethers,
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

    const taxiTree = await getContractAddress(hre, 'MockTaxiTree', '');
    const busTreeProxy = await getContractAddress(hre, 'MockBusTree_Proxy', '');
    const ferryTree = await getContractAddress(hre, 'PantherFerryTree', '');
    const staticTreeProxy = await getContractAddress(
        hre,
        'PantherStaticTree_Proxy',
        '',
    );

    // const {abi} = await artifacts.readArtifact('ITreeRootGetter');

    // const addresses = [taxiTree, busTreeProxy, ferryTree, staticTreeProxy];
    // for (let index = 0; index < addresses.length; index++) {
    //     const tree = await ethers.getContractAt(abi, addresses[index]);
    //     const root = await tree.getRoot();
    //     console.log({root});
    // }

    const pantherVerifier = await getContractAddress(
        hre,
        'PantherVerifier',
        'PANTHER_VERIFIER',
    );

    const poseidonT5 =
        getContractEnvAddress(hre, 'POSEIDON_T5') ||
        (await get('PoseidonT5')).address;

    await deploy('PantherPoolV1_Implementation', {
        contract: 'MockPantherPoolV1',
        from: deployer,
        args: [
            multisig,
            vaultProxy,
            taxiTree,
            busTreeProxy,
            ferryTree,
            staticTreeProxy,
            pantherVerifier,
        ],
        libraries: {
            PoseidonT5: poseidonT5,
        },
        log: true,
        autoMine: true,
    });
};

export default func;

func.tags = ['forest', 'protocol', 'ff'];
func.dependencies = ['check-params'];
