import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const pantherPoolAddress = await getContractAddress(
        hre,
        'PantherPoolV1_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('MockPantherPoolV1');
    const pantherPool = await ethers.getContractAt(abi, pantherPoolAddress);

    const root = await pantherPool.getRoot();
    if (
        root ==
        '0x0000000000000000000000000000000000000000000000000000000000000000'
    ) {
        console.log('initialize panther forest', root);

        const tx = await pantherPool.initialize();
        const res = await tx.wait();
        console.log('Transaction confirmed', res.transactionHash);
    } else {
        console.log('Forest is already initialized', root);
    }
};

export default func;

func.tags = ['init-forest', 'protocol'];
