import * as path from 'path';
import {expect} from 'chai';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';

describe('ZAssetChecker circuit', async function (this: any) {
    let zAssetChecker: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/zAssetCheckerMain.circom',
        );
        zAssetChecker = await wasm_tester(input, opts);
    });

    let zAssetCheckerSignals: any;
    beforeEach(async function () {
        zAssetCheckerSignals = {
            token: 0,
            tokenId: 0,
            zAssetId: 0,
            zAssetToken: 0,
            zAssetTokenId: 0,
            zAssetOffset: 0,
            depositAmount: 0,
            withdrawAmount: 0,
            utxoZAssetId: 0,
        };
    });

    const checkWitness = async (expectedOut: any) => {
        const witness = await zAssetChecker.calculateWitness(
            zAssetCheckerSignals,
            true,
        );
        await zAssetChecker.checkConstraints(witness);
        await zAssetChecker.assertOut(witness, expectedOut);
    };

    const checkWitnessError = async (zAssetCheckerSignals: any) => {
        try {
            await zAssetChecker.calculateWitness(zAssetCheckerSignals, true);
            console.log(
                `Unexpectedly Circom did not throw an error for input signal ${JSON.stringify(
                    zAssetCheckerSignals,
                )}`,
            );
            throw new Error(`This code should never be reached!`);
        } catch (err) {
            expect(err).to.be.instanceOf(Error);
        }
    };

    describe('Valid input signals', async function () {
        // enable_If_ExternalAmountsAre_NOT_Zero - Either deposit or withdraw
        describe('Deposit/Withdraw transaction', async function () {
            // Native token case
            it('when Native token is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                // Always checked irrespective of the type of transaction
                // $ZKP (ERC-20). MUST be in the 1st Batch with `zAssetsBatchId` of 0
                zAssetCheckerSignals.zAssetId = 0;
                // `zAssetId` for $ZKP MUST be 0.
                zAssetCheckerSignals.utxoZAssetId = 0;

                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 1,
                });
            });

            it('when ERC20 ZAsset is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                // Always checked irrespective of the type of transaction
                // ERC-20 token in the 10th Batch with `zAssetsBatchId` being (10-1)*2^32+0
                zAssetCheckerSignals.zAssetId = (10 - 1) * 2 ** 32 + 0;
                // The ERC-20 token from Example 3) has the `zAssetId` of (10-1)*2^32+0.
                zAssetCheckerSignals.utxoZAssetId = (10 - 1) * 2 ** 32 + 0;

                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 0,
                });
            });

            it('when ERC-721 ZKP ZAsset is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                // NFT with tokenId 56 in the 11th Batch with `zAssetsBatchId` (11-1)*2^32+0
                // (`startTokenId` being 56, and `tokenIdsRangeSize` being 0)
                zAssetCheckerSignals.zAssetTokenId = 56;
                zAssetCheckerSignals.tokenId = 56;
                zAssetCheckerSignals.zAssetOffset = 0;

                // Always checked irrespective of the type of transaction
                zAssetCheckerSignals.zAssetId = (11 - 1) * 2 ** 32 + 0;
                zAssetCheckerSignals.utxoZAssetId = (11 - 1) * 2 ** 32 + 0;

                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 0,
                });
            });

            it('when ERC-1155 deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    0x112233445566778899aabbccddeeff0011223344n;
                zAssetCheckerSignals.token =
                    0x112233445566778899aabbccddeeff0011223344n;

                // 33 NFTs with the tokenId's from 167 to 199 in the 12th Batch.
                // `zAssetsBatchId` is (12-1)*2^32+0
                // NFT from the Example 4) with `tokenId` 173 has `zAssetId` of 11*2^32+6.
                zAssetCheckerSignals.zAssetTokenId = 167;
                zAssetCheckerSignals.tokenId = 173;
                zAssetCheckerSignals.zAssetOffset = 6; // targeting 173 tokenID with this offset

                // Always checked irrespective of the type of transaction
                zAssetCheckerSignals.zAssetId = (12 - 1) * 2 ** 32 + 0;
                zAssetCheckerSignals.utxoZAssetId = (12 - 1) * 2 ** 32 + 6;

                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 0,
                });
            });
        });

        // enable_If_ExternalAmountsAre_Zero - No deposit or withdraw
        describe('Internal transaction should pass', async function () {
            // Native token internal tx
            it('when external token and external tokenId is 0', async () => {
                zAssetCheckerSignals.zAssetId = 0; // zZKP token
                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 1,
                });
            });

            // ERC-20 token internal tx
            it('when external token and external tokenId is 0', async () => {
                zAssetCheckerSignals.zAssetId = 1; // ERC-20 token
                const wtns = await zAssetChecker.calculateWitness(
                    zAssetCheckerSignals,
                    true,
                );

                const wtnsFormattedOutput = [0, wtns[11]];

                await zAssetChecker.assertOut(wtnsFormattedOutput, {
                    isZkpToken: 0,
                });
            });
        });
    });

    describe('Inalid input signals', async function () {
        describe('Deposit transaction should fail', async () => {
            it('when zAssetTokenId > 2**254', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.zAssetTokenId =
                    BigInt(2 ** 254) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when tokenId > 2**254', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.tokenId = BigInt(2 ** 254) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when offset > 33', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.offset = 34;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when utxoZAssetId > 2**64', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.utxoZAssetId = BigInt(2 ** 64) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external token is not equal to zAssetToken', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken = 36; // Wrong value

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external tokenId is not equal to zAssetTokenId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 1; // Wrong value
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when zAsset ID is not equal to utxoZAssetId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                zAssetCheckerSignals.zAssetId = 0;
                zAssetCheckerSignals.utxoZAssetId = 1; // Wrong value

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external tokenId is not equal to utxoZAssetId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.depositAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 11;

                zAssetCheckerSignals.zAssetId = 1;
                zAssetCheckerSignals.utxoZAssetId = 1;

                await checkWitnessError(zAssetCheckerSignals);
            });
        });

        describe('Withdraw transaction should fail', async () => {
            it('when zAssetTokenId > 2**254', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.zAssetTokenId =
                    BigInt(2 ** 254) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when tokenId > 2**254', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.tokenId = BigInt(2 ** 254) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when offset > 33', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.offset = 34;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when utxoZAssetId > 2**64', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.utxoZAssetId = BigInt(2 ** 64) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external token is not equal to zAssetToken', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken = 36; // Wrong value

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external tokenId is not equal to zAssetTokenId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 1; // Wrong value
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when zAsset ID is not equal to utxoZAssetId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                zAssetCheckerSignals.zAssetId = 0;
                zAssetCheckerSignals.utxoZAssetId = 1; // Wrong value

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external tokenId is not equal to utxoZAssetId with respect to zAssetOffset', async () => {
                zAssetCheckerSignals.withdrawAmount = 100;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 11;

                zAssetCheckerSignals.zAssetId = 1;
                zAssetCheckerSignals.utxoZAssetId = 1;

                await checkWitnessError(zAssetCheckerSignals);
            });
        });

        describe('Internal transaction should fail', async () => {
            it('when zAssetId > 2**64', async () => {
                zAssetCheckerSignals.zAssetId = BigInt(2 ** 64) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when utxoZAssetId > 2**64', async () => {
                zAssetCheckerSignals.utxoZAssetId = BigInt(2 ** 64) + BigInt(1);

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when offset > 33', async () => {
                zAssetCheckerSignals.offset = 34;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external token is not equal to 0', async () => {
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when external tokenId is not equal to 0', async () => {
                zAssetCheckerSignals.tokenId = 1;

                await checkWitnessError(zAssetCheckerSignals);
            });

            it('when zAsset ID is not equal to utxoZAssetId with respect to zAssetOffset', async () => {
                // As zAssetId is 0
                zAssetCheckerSignals.utxoZAssetId = 1; // Wrong value

                await checkWitnessError(zAssetCheckerSignals);
            });
        });
    });
});
