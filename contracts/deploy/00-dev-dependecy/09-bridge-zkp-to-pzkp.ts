// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal, isProd} from '../../lib/checkNetwork';
import {getContractAddress} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (isProd(hre) || isLocal(hre)) return;

    const {artifacts, ethers} = hre;

    const zkpAddress = await getContractAddress(hre, 'PZkp_token', 'ZKP_TOKEN');

    const mockRootChainManagerProxy = await getContractAddress(
        hre,
        'MockRootChainManager_Proxy',
        '',
    );

    const {abi: zkpAbi} = await artifacts.readArtifact('ERC20');
    const {abi: MockRootChainManagerAbi} = await artifacts.readArtifact(
        'MockRootChainManager',
    );

    const zkp = await ethers.getContractAt(zkpAbi, zkpAddress);
    const mockRootChainManager = await ethers.getContractAt(
        MockRootChainManagerAbi,
        mockRootChainManagerProxy,
    );

    console.log({zkpAddress, mockRootChainManagerProxy});

    console.log('Bridging...');

    const receiver = '0x02B5C527a5c335367b999142D8Ab862140e9aBD7';
    const amount = ethers.utils.parseEther('10000');

    const data = ethers.utils.defaultAbiCoder.encode(
        ['uint256'],
        [amount.toString()],
    );

    await zkp.approve(mockRootChainManagerProxy, amount);

    const tx = await mockRootChainManager.depositFor(
        receiver,
        zkpAddress,
        data,
    );

    const res = await tx.wait();

    console.log('Transaction confirmed', res.transactionHash);
};

export default func;

func.tags = ['bridge-zkp'];
