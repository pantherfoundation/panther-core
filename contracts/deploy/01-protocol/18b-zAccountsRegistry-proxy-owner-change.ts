import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts, ethers} = hre;
    const {deployer} = await getNamedAccounts();
    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const zAccountRegistry = await ethers.getContract(
        'ZAccountsRegistry_Proxy',
    );

    const oldOwner = await zAccountRegistry.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(
            `ZAccountsRegistry_Proxy owner is already set to: ${multisig}`,
        );
    } else {
        console.log(
            `Transferring ownership of ZAccountsRegistry_Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await zAccountRegistry
            .connect(signer)
            .transferOwnership(multisig);

        console.log('ZAccountsRegistry_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['z-accounts-registry-owner', 'protocol'];
