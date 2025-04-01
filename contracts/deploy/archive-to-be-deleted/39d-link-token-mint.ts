// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function () {
    const oneToken = ethers.constants.WeiPerEther;

    const proxyAddr = '0xA82B5942DD61949Fd8A2993dCb5Ae6736F8F9E60';

    const linkToken = await ethers.getContractAt('MockLinkToken', proxyAddr);

    const tx = await linkToken.mint(
        '0xE67D10656eF5d337372021AC513ABd51697c5CC5',
        oneToken.mul(1e6),
    );

    console.log(tx.hash);

    await tx.wait();
};

export default func;

func.tags = ['link-token-mint'];
func.dependencies = ['check-params', 'deployment-consent'];
