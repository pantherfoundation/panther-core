// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers} from 'hardhat';

import {
    getSelectors,
    FacetCutAction,
    deployDiamondWithCutFacet,
    cutDiamond,
} from '../../../lib/diamond.ts';
import {
    Diamond,
    DiamondCutFacet,
    DiamondLoupeFacet,
    IDiamondCut,
    IDiamondLoupe,
} from '../../../types/contracts';

describe('Diamond', function () {
    let diamondProxy: Diamond;
    let diamondCutFacet: DiamondCutFacet;
    let owner: SignerWithAddress, nonOwner: SignerWithAddress;

    before(async () => {
        [, owner, nonOwner] = await ethers.getSigners();

        const result = await deployDiamondWithCutFacet(owner, owner.address);
        diamondProxy = result.diamond;
        diamondCutFacet = result.diamondCutFacet;
    });

    describe('Add loupe facet', () => {
        let diamondLoupeFacet: DiamondLoupeFacet;
        let cut: IDiamondCut.FacetCutStruct;

        before(async () => {
            diamondLoupeFacet = (await (
                await ethers.getContractFactory('DiamondLoupeFacet')
            ).deploy()) as DiamondLoupeFacet;

            cut = {
                facetAddress: diamondLoupeFacet.address,
                action: FacetCutAction.Add,
                functionSelectors: getSelectors(diamondLoupeFacet),
            };
        });

        it('should add diamond loupe facet', async () => {
            const tx = await cutDiamond(owner, diamondProxy.address, cut);
            const res = await tx.wait();

            expect(res.events[0].event).to.be.eq('DiamondCut');
        });

        it('should get facets via loupe', async () => {
            const diamond = (await ethers.getContractAt(
                'IDiamondLoupe',
                diamondProxy.address,
            )) as IDiamondLoupe;

            const facets = await diamond.facets();
            const facetAddresses = await diamond.facetAddresses();
            const facetOfSelector = await diamond.facetAddress(
                getSelectors(diamondLoupeFacet)[0],
            );
            const selectorsOfFacet = await diamond.facetFunctionSelectors(
                diamondLoupeFacet.address,
            );

            expect(facets.length).to.be.eq(2);
            expect(facetAddresses).to.have.members([
                diamondLoupeFacet.address,
                diamondCutFacet.address,
            ]);

            expect(facetOfSelector).to.be.eq(diamondLoupeFacet.address);
            expect(selectorsOfFacet).to.have.members(
                getSelectors(diamondLoupeFacet),
            );
        });

        it('should revet when executed by non-owner', async () => {
            try {
                await cutDiamond(nonOwner, diamondProxy.address, cut);
            } catch (error) {
                expect(error.message).to.contain(
                    'LibDiamond: Must be contract owner',
                );
            }
        });
    });
});
