import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {
    getContractAddress,
    verifyUserConsentOnProd,
} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {getNamedAccounts, artifacts, ethers} = hre;
    const {deployer} = await getNamedAccounts();

    await verifyUserConsentOnProd(hre, deployer);

    const busTreeAddress = await getContractAddress(
        hre,
        'MockBusTree_Proxy',
        'MOCK_BUS_TREE_PROXY',
    );

    const {abi} = await artifacts.readArtifact('MockBusTree');
    const busTree = await ethers.getContractAt(abi, busTreeAddress);

    const perMinuteUtxosLimit = 13;
    const basePerUtxoReward = ethers.utils.parseUnits('1', 17);
    const reservationRate = '2000';
    const premiumRate = '10';
    const minEmptyQueueAge = '100';

    console.log(
        `Updating reward params for bus tree, perMinuteUtxosLimit: ${perMinuteUtxosLimit}, ` +
            `basePerUtxoReward: ${basePerUtxoReward}, reservationRate: ${reservationRate}, ` +
            `premiumRate: ${premiumRate}, ` +
            `minEmptyQueueAge: ${minEmptyQueueAge}`,
    );

    const tx = await busTree.updateParams(
        perMinuteUtxosLimit,
        basePerUtxoReward,
        reservationRate,
        premiumRate,
        minEmptyQueueAge,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};
export default func;

func.tags = ['bus-tree-update-params', 'forest', 'protocol'];
func.dependencies = ['bus-tree'];
