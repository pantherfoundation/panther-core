import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {getNamedAccounts, ethers} = hre;
    const {deployer} = await getNamedAccounts();
    const multisig =
        process.env.DAO_MULTISIG_ADDRESS ||
        (await getNamedAccounts()).multisig ||
        deployer;

    const busTreeProxy = await ethers.getContract('PantherBusTree_Proxy');

    const oldOwner = await busTreeProxy.owner();
    if (oldOwner.toLowerCase() == multisig.toLowerCase()) {
        console.log(`BusTree_Proxy owner is already set to: ${multisig}`);
    } else {
        console.log(
            `Transferring ownership of BusTree_Proxy to ${multisig}...`,
        );

        const signer = await ethers.getSigner(deployer);
        const tx = await busTreeProxy
            .connect(signer)
            .transferOwnership(multisig);

        console.log('BusTree_Proxy owner is updated, tx: ', tx.hash);
    }
};

export default func;

func.tags = ['bus-tree-owner', 'protocol'];
func.dependencies = ['check-params', 'bus-tree'];
