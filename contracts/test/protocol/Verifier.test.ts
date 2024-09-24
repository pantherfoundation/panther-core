// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import fs from 'fs';
import path from 'path';

import {FullProof} from '@panther-core/crypto/lib/base/groth16';
import {SnarkProofStruct} from '@panther-core/dapp/src/types/contracts/PantherPoolV1';
import {expect} from 'chai';
import {BigNumber} from 'ethers';
import hre, {ethers} from 'hardhat';
import {groth16} from 'snarkjs';

import {
    setDeterministicDeploymentProxy,
    getDeterministicDeploymentProxyAddressAndCode,
    deployContentDeterministically,
} from '../../lib/deploymentHelpers';
import {encodeVerificationKey} from '../../lib/encodeVerificationKey';
import {MockVerifier} from '../../types/contracts';

describe('Verifier', function () {
    const provider = ethers.provider;

    const {deployerAddr} = getDeterministicDeploymentProxyAddressAndCode();

    const additionVerificationKey = JSON.parse(
        fs.readFileSync(
            path.join(
                __dirname,
                'data/circuits/compiled/addition_verification_key.json',
            ),
        ),
    );

    let verifier: MockVerifier;
    let cirquitId: string;

    let encodedVerificationKey2: string;

    it('deploy deployer', async () => {
        await setDeterministicDeploymentProxy(hre);

        expect((await provider.getCode(deployerAddr)).length).to.be.gt(2);
    });

    it('should deploy VerificationKeys', async function () {
        encodedVerificationKey2 = encodeVerificationKey(
            additionVerificationKey,
        );

        const {pointer} = await deployContentDeterministically(
            hre,
            encodedVerificationKey2,
        );

        cirquitId = pointer;

        expect((await provider.getCode(pointer)).length).to.be.gt(2);
    });

    it('should deploy MockVerifier', async function () {
        const MockVerifier = await ethers.getContractFactory('MockVerifier');

        verifier = await MockVerifier.deploy();

        expect((await provider.getCode(verifier.address)).length).to.be.gt(2);
    });

    it('should getkeys from MockVerifier', async function () {
        const onchainVerifyingKey = await verifier.getVerifyingKey(cirquitId);

        const keyAsBigNumber = BigNumber.from(onchainVerifyingKey[0][0]);

        const verifyingKeyFromFile = additionVerificationKey.vk_alpha_1[0];

        expect(keyAsBigNumber).to.eql(BigNumber.from(verifyingKeyFromFile));
    });

    it('should not verify mock proof', async function () {
        const placeholder = BigNumber.from(0);
        const proof = {
            a: {x: placeholder, y: placeholder},
            b: {
                x: [placeholder, placeholder],
                y: [placeholder, placeholder],
            },
            c: {x: placeholder, y: placeholder},
        } as SnarkProofStruct;

        const inputArray: number[] = [7];

        await expect(
            verifier.verifyOrRevert(cirquitId, inputArray, proof),
        ).to.be.revertedWith('verification-failed');
    });

    it('should verify inputs and proof', async function () {
        const {pi_a, pi_b, pi_c} = JSON.parse(
            fs.readFileSync(
                path.join(
                    __dirname,
                    'data/circuits/compiled/addition_js/proof.json',
                ),
            ),
        );

        const proof: SnarkProofStruct = {
            a: {x: pi_a[0], y: pi_a[1]},
            b: {
                x: [pi_b[0][1], pi_b[0][0]],
                y: [pi_b[1][1], pi_b[1][0]],
            },
            c: {x: pi_c[0], y: pi_c[1]},
        };

        const seven = BigNumber.from('5');

        await expect(verifier.verifyOrRevert(cirquitId, [seven], proof)).to.be
            .not.reverted;
    });

    it('should verify groth16 from file', async function () {
        const fullProof: FullProof = {
            proof: JSON.parse(
                fs.readFileSync(
                    path.join(
                        __dirname,
                        'data/circuits/compiled/addition_js/proof.json',
                    ),
                ),
            ),
            publicSignals: ['5'],
        };

        const vk = JSON.parse(
            fs.readFileSync(
                path.join(
                    __dirname,
                    'data/circuits/compiled/addition_verification_key.json',
                ),
            ),
        );

        expect(
            await groth16.verify(vk, fullProof.publicSignals, fullProof.proof),
        ).to.be.true;
    });
});
