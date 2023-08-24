import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

// TODO To be deleted after implementing panther pool v1
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre)) return;

    const {artifacts, ethers} = hre;

    const onboardingControllerAddress = await getContractAddress(
        hre,
        'OnboardingController_Proxy',
        '',
    );
    const prpVoucherGrantorAddress = await getContractAddress(
        hre,
        'PrpVoucherGrantor_Proxy',
        '',
    );

    const {abi} = await artifacts.readArtifact('PrpVoucherGrantor');

    const prpVoucherGrantor = await ethers.getContractAt(
        abi,
        prpVoucherGrantorAddress,
    );

    console.log('Update voucher terms...');

    const onboardingGrantType = '0x93b212ae';

    const amount = ethers.BigNumber.from(500);
    const limit = amount.mul(3);
    const enabled = true;

    const tx = await prpVoucherGrantor.updateVoucherTerms(
        onboardingControllerAddress,
        onboardingGrantType,
        limit,
        amount,
        enabled,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['update-voucher-terms', 'protocol'];
