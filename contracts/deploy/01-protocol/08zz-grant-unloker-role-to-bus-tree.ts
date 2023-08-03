import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

// TODO To be deleted after implementing panther pool v1
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {artifacts, ethers} = hre;

    const busTreeAddress = await getContractAddress(
        hre,
        'MockBusTree_Proxy',
        'BUS_TREE',
    );
    const poolV1Address = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        'PANTHER_POOL_V1_PROXY',
    );
    const {abi} = await artifacts.readArtifact('MockPantherPoolV1');

    const poolV1 = await ethers.getContractAt(abi, poolV1Address);

    console.log('Granting unlocker role to the bus tree contract');

    const tx = await poolV1.updateVaultAssetUnlocker(busTreeAddress, true);
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['grant-unlocker-role', 'protocol'];
func.dependencies = ['check-params', 'pool-v1', 'bus-tree'];
