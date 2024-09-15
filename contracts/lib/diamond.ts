// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {ethers} from 'hardhat';

import {Diamond, DiamondCutFacet, IDiamondCut} from '../types/contracts';

export const FacetCutAction = {Add: 0, Replace: 1, Remove: 2};

export function getSelectors(contract: ethers.Contract) {
    const signatures: any = Object.keys(contract.interface.functions);
    const selectors = signatures.reduce((acc: string[], val: string) => {
        if (val !== 'init(bytes)') {
            acc.push(contract.interface.getSighash(val));
        }
        return acc;
    }, []);

    return selectors;
}

export async function deployDiamondWithCutFacet(
    signer: SignerWithAddress,
    owner: string,
) {
    const diamondCutFacet = (await (
        await ethers.getContractFactory('DiamondCutFacet')
    )
        .connect(signer)
        .deploy()) as DiamondCutFacet;

    const diamond = (await (await ethers.getContractFactory('Diamond'))
        .connect(signer)
        .deploy(owner, diamondCutFacet.address)) as Diamond;

    return {diamond, diamondCutFacet};
}

export async function cutDiamond(
    signer: SignerWithAddress,
    diamondAddress: string,
    cut: IDiamondCut.FacetCutStruct,
    initAddress = ethers.constants.AddressZero,
    initData = '0x00',
) {
    const cuts: IDiamondCut.FacetCutStruct[] = [];
    cuts.push(cut);

    const diamond = await ethers.getContractAt('IDiamondCut', diamondAddress);

    return await diamond
        .connect(signer)
        .diamondCut(cuts, initAddress, initData);
}
