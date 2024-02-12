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
            './test/circuits/zAssetChecker.circom',
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
        describe('Deposit/Withdraw transaction should pass', async function () {
            // Case - ERC-20 - ZKP case (zAssetId is 0)
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            it('when ERC20 ZKP ZAsset is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                await checkWitness({
                    isZkpToken: 1,
                });
            });

            // Case - ERC-20 - Non ZKP case (zAssetId is !0)
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            // zAssetId must be non-zero
            it('when ERC20 Non-ZKP ZAsset is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId = 0;
                zAssetCheckerSignals.tokenId = 0;
                zAssetCheckerSignals.zAssetOffset = 0;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = counter << 32;

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (zAssetCheckerSignals.tokenId & lsbMask);

                await checkWitness({
                    isZkpToken: 0,
                });
            });

            // Case - ERC-721 - ZKP case (zAssetId is 0)
            // This is a valid case atleast from circuit perspective.
            // This case needs to be checked from the smart contract end.
            it('when ERC-721 ZKP ZAsset is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId =
                    (0xcc00ffeecc00ffeen >> 0n) << 0n;
                zAssetCheckerSignals.tokenId = 0xcc00ffeecc00ffeen;
                zAssetCheckerSignals.zAssetOffset = 0;

                await checkWitness({
                    isZkpToken: 1,
                });
            });

            // Case - ERC-721 - Non ZKP case (zAssetId is !0) - with offset 0
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            // zAssetId must be non-zero
            // utxoZAssetId is computed accordingly
            it('when ERC-721 Non-ZKP ZAsset with offset 0 is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId =
                    (0xcc00ffeecc00ffeen >> 0n) << 0n;
                zAssetCheckerSignals.tokenId = 0xcc00ffeecc00ffeen;
                zAssetCheckerSignals.zAssetOffset = 0;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = counter << 32;

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (Number(zAssetCheckerSignals.tokenId) & lsbMask);

                await checkWitness({
                    isZkpToken: 0,
                });
            });

            // Case - ERC-1155 - Non ZKP case (zAssetId is !0) - with offset 2
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            // zAssetId must be non-zero
            // utxoZAssetId is computed accordingly
            it('when ERC-1155 Non-ZKP ZAsset with offset 2 is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetTokenId =
                    (0xcc00ffeecc00ffeen >> 2n) << 2n;
                zAssetCheckerSignals.tokenId = 0xcc00ffeecc00ffeen;
                zAssetCheckerSignals.zAssetOffset = 2;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = counter << 32;

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (Number(zAssetCheckerSignals.tokenId) & lsbMask);

                await checkWitness({
                    isZkpToken: 0,
                });
            });

            // Case - ERC-1155 - Non ZKP case (zAssetId is !0) - with offset 32
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            // zAssetId must be non-zero
            // utxoZAssetId is computed accordingly
            it('when ERC-1155 Non-ZKP ZAsset with offset 32 is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    365481738974395054943628650313028055219811856521n;
                zAssetCheckerSignals.token =
                    365481738974395054943628650313028055219811856521n;

                zAssetCheckerSignals.zAssetOffset = 32;
                zAssetCheckerSignals.zAssetTokenId =
                    (0xcc00ffeecc00ffeen >> 32n) << 32n;
                zAssetCheckerSignals.tokenId = 0xcc00ffeecc00ffeen;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = BigInt(counter) << BigInt(32);

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (BigInt(zAssetCheckerSignals.tokenId) & BigInt(lsbMask));

                await checkWitness({
                    isZkpToken: 0,
                });
            });

            // ======================Computation from zAsset-Registry doc===================================================
            /*
            token AKA Ext.tokenAddr = 0x112233445566778899aabbccddeeff0011223344
            zAssetToken AKA Leaf.tokenAddr = 0x112233445566778899aabbccddeeff0011223344

            zAssetOffset AKA Leaf.offset = 32

            tokenId AKA Ext.tokenId = 0xcc00ffeecc00ffee - 14700030584827215854
            zAssetTokenId AKA Leaf.tokenId:
                Formula = (Ext.tokenId >> Leaf.offset) << Leaf.offset = 
                        = (0xcc00ffeecc00ffee >> 32) << 32 = 0xcc00ffee00000000

                        = (14700030584827215854 >> 32) << 32 
                        = (-872349696) << 32

            COUNTER = 0xabba
            zAssetId AKA Leaf.zAssetId:
                Formula = COUNTER << 32
                        = 0xabba << 32 = 0xabba00000000
            zAssetId - 0xabba00000000 - 188815352266752

            utxoZAssetId AKA Utxo.AssetId:
            -----------------------------
            lsbMask = 2**L.offset - 1
            Utxo.zAssetId = Leaf.zAssetId + (Ext.tokenId & lsbMask)

            lsbMask = 0xffffffff - 4294967295
            Utxo.AssetId = 0xabba00000000 + 0xcc00ffeecc00ffee & 0xffffffff
                         = 0xabba00000000 + cc00ffee
                         = 0xabbacc00ffee

            Utxo.AssetId = 188815352266752 + 14700030584827215854 & 4294967295
                         = 188815352266752 + 3422617582
                         = 188818774884334

            */
            // Case - ERC-1155 - Non ZKP case (zAssetId is !0) - with offset 32
            // External token address AKA token & Internal token address AKA zAssetToken must be same
            // zAssetId must be non-zero
            // utxoZAssetId is computed accordingly
            it('when ERC-1155 Non-ZKP ZAsset with offset 32 is deposited/withdrawn', async () => {
                zAssetCheckerSignals.depositAmount = 100;

                zAssetCheckerSignals.zAssetToken =
                    0x112233445566778899aabbccddeeff0011223344n;
                zAssetCheckerSignals.token =
                    0x112233445566778899aabbccddeeff0011223344n;

                zAssetCheckerSignals.zAssetTokenId =
                    (0xcc00ffeecc00ffeen >> 32n) << 32n;
                zAssetCheckerSignals.tokenId = 0xcc00ffeecc00ffeen;
                zAssetCheckerSignals.zAssetOffset = 32;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = BigInt(counter) << BigInt(32);

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (BigInt(zAssetCheckerSignals.tokenId) & BigInt(lsbMask));

                await checkWitness({
                    isZkpToken: 0,
                });
            });
            // ======================Computation from zAsset-Registry doc===================================================
        });

        describe('Internal transfer transaction should pass', async function () {
            // Case - Internal Transfer of zZAssets
            // External depositAmount and withdrawAmount must be 0
            // token and tokenId must be 0
            it('when zZAsset is transfered within the MASP', async () => {
                zAssetCheckerSignals.zAssetOffset = 32;

                let counter = 0xabba;
                zAssetCheckerSignals.zAssetId = BigInt(counter) << BigInt(32);

                // computation of utxoZAssetId
                let lsbMask = 2 ** zAssetCheckerSignals.zAssetOffset - 1;
                zAssetCheckerSignals.utxoZAssetId =
                    zAssetCheckerSignals.zAssetId +
                    (BigInt(zAssetCheckerSignals.tokenId) & BigInt(lsbMask));

                await checkWitness({
                    isZkpToken: 0,
                });

                await checkWitness({
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
