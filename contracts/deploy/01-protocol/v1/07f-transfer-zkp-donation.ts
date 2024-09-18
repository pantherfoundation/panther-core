// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const pzkp = await getNamedAccount(hre, 'pzkp');

    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('FeeMaster');
    const {address} = await get('FeeMaster_Proxy');
    const feeMaster = await ethers.getContractAt(abi, address);

    const zkpTokenReserves = ethers.utils.parseEther('100000');
    {
        const pZkp = await ethers.getContractAt('MockPZkp', pzkp);

        console.log('transfering zkp tokens...');
        const tx = await pZkp.transfer(feeMaster.address, zkpTokenReserves, {
            gasPrice: 30000000000,
        });
        const res = await tx.wait();
        console.log('zkp tokens are transfered', res.transactionHash);
    }

    {
        console.log('increaseing zkp donation...');
        const tx = await feeMaster.increaseZkpTokenDonations(zkpTokenReserves, {
            gasPrice: 30000000000,
        });
        const res = await tx.wait();
        console.log('zkp donation is updated', res.transactionHash);
    }
};

export default func;

func.tags = ['transfer-fee-master-zkp-donation', 'core', 'protocol-v1'];
func.dependencies = ['fee-master', 'add-fee-master-total-debt-controller'];
