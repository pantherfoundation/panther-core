// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

// TODO To be deleted after implementing panther pool v1
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {artifacts, ethers} = hre;

    const polygonPrpRewardMsgRelayerAddress = await getContractAddress(
        hre,
        'PolygonPrpRewardMsgRelayer',
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

    const type = '0x53a1eb85';

    const amount = ethers.BigNumber.from(100);
    const limit = amount.mul(5);
    const enabled = true;

    const tx = await prpVoucherGrantor.updateVoucherTerms(
        polygonPrpRewardMsgRelayerAddress,
        type,
        limit,
        amount,
        enabled,
    );
    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['update-voucher-terms-bridge', 'protocol'];
