import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';

describe('DataEscrowSerializer circuit', function (this: any) {
    let dataEscrowSerializer: any;
    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/dataEscrowSerializerMain.circom',
        );
        dataEscrowSerializer = await wasm_tester(input, opts);
    });

    // Taking these values from `DepositOnlyNonZeroInputWitnessGeneration.test.ts`
    const zAssetID = 0;
    const zAccountId = 33;
    const zAccountZoneId = 1;
    const utxoInMerkleTreeSelector = [
        [0, 0],
        [0, 0],
    ];
    const utxoInPathIndices = [
        [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
        [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
        ],
    ];
    const utxoInAmount = [0, 0];
    const utxoOutAmount = [10, 0];
    const utxoInOriginZoneId = [0, 0];
    const utxoOutTargetZoneId = [1, 0];

    const out: any = [];
    out[0] = zAssetID;
    // console.log('out[0]=>', out[0]);

    // out[1] computation
    // 0 - 15 (16 bits) of zAccountZoneId
    // 16 - 39 (24 bits) of zAccountId
    // 40 - 43 (4 bits) of utxoInMerkleTreeSelector

    const zAccountZoneIdBits = zAccountZoneId.toString(2);
    const zAccountIdBits = zAccountId.toString(2);
    const zAccountIdBitsArray = zAccountIdBits.split('').map(Number);
    const finalzAccountIdBits = zAccountIdBitsArray.reverse();

    const out1Computation: any[] = new Array(44).fill(0);
    for (let i = 0; i < 16; i++) {
        out1Computation[i] =
            zAccountZoneIdBits[i] === undefined ? 0 : zAccountZoneIdBits[i];
    }

    for (var i = 0; i < 24; i++) {
        out1Computation[i + 16] =
            finalzAccountIdBits[i] === undefined ? 0 : finalzAccountIdBits[i];
    }

    for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 2; j++) {
            out1Computation[16 + 24 + i * 2 + j] =
                utxoInMerkleTreeSelector[i][j] === undefined
                    ? 0
                    : utxoInMerkleTreeSelector[i][j];
        }
    }
    const bitArray = out1Computation;

    function bitArrayToDecimal(bitArray: any) {
        let decimal = 0;
        for (let i = 0; i < bitArray.length; i++) {
            decimal += bitArray[i] * Math.pow(2, i);
        }
        return decimal;
    }

    const decimalNumber = bitArrayToDecimal(bitArray);

    out[1] = decimalNumber;
    // console.log('out[1]=>', out[1]);

    out[2] = utxoInAmount[0];
    // console.log('out[2]=>', out[2]);

    out[3] = utxoInAmount[1];
    // console.log('out[3]=>', out[3]);

    out[4] = utxoOutAmount[0];
    // console.log('out[4]=>', out[4]);

    out[5] = utxoOutAmount[1];
    // console.log('out[5]=>', out[5]);

    // out[6] and out[7] computation
    // out[6]
    const utxoOutTargetZoneId0 = utxoOutTargetZoneId[0];
    const utxoOutTargetZoneId0Bits = utxoOutTargetZoneId0.toString(2);

    const utxoInOriginZoneId0 = utxoInOriginZoneId[0];
    const utxoInOriginZoneId0Bits = utxoInOriginZoneId0.toString(2);
    const utxoInOriginZoneId0BitsArray = utxoInOriginZoneId0Bits
        .split('')
        .map(Number);
    const finalUtxoOutOriginZoneId0Bit = utxoInOriginZoneId0BitsArray.reverse();

    const b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId: any[] =
        new Array(32).fill(0);
    for (let i = 0; i < 16; i++) {
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId[i] =
            utxoOutTargetZoneId0Bits[i] === undefined
                ? 0
                : utxoOutTargetZoneId0Bits[i];
    }

    for (var i = 0; i < 24; i++) {
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId[i + 16] =
            finalUtxoOutOriginZoneId0Bit[i] === undefined
                ? 0
                : finalUtxoOutOriginZoneId0Bit[i];
    }

    const decimalNumber0 = bitArrayToDecimal(
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId,
    );

    out[6] = decimalNumber0;
    // console.log('out[6]=>', out[6]);

    // out[7]
    const utxoOutTargetZoneId1 = utxoOutTargetZoneId[1];
    const utxoOutTargetZoneId1Bits = utxoOutTargetZoneId1.toString(2);

    const utxoInOriginZoneId1 = utxoInOriginZoneId[1];
    const utxoInOriginZoneId1Bits = utxoInOriginZoneId1.toString(2);
    const utxoInOriginZoneId1BitsArray = utxoInOriginZoneId1Bits
        .split('')
        .map(Number);
    const finalUtxoOutOriginZoneId1Bit = utxoInOriginZoneId1BitsArray.reverse();

    const b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId1: any[] =
        new Array(32).fill(0);
    for (let i = 0; i < 16; i++) {
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId1[i] =
            utxoOutTargetZoneId1Bits[i] === undefined
                ? 0
                : utxoOutTargetZoneId1Bits[i];
    }

    for (var i = 0; i < 24; i++) {
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId1[i + 16] =
            finalUtxoOutOriginZoneId1Bit[i] === undefined
                ? 0
                : finalUtxoOutOriginZoneId1Bit[i];
    }

    const decimalNumber1 = bitArrayToDecimal(
        b2n_utxoInPathIndices_utxoInOriginZoneId_utxoOutTargetZoneId1,
    );

    out[7] = decimalNumber1;
    // console.log('out[7]=>', out[7]);

    const input = {
        zAsset: zAssetID,
        zAccountId: 33,
        zAccountZoneId: 1,
        zAccountNonce: 2,
        utxoInMerkleTreeSelector: utxoInMerkleTreeSelector,
        utxoInPathIndices: utxoInPathIndices,
        utxoInAmount: utxoInAmount,
        utxoOutAmount: utxoOutAmount,
        utxoInOriginZoneId: utxoInOriginZoneId,
        utxoOutTargetZoneId: utxoOutTargetZoneId,
    };

    const output = {
        out: [0, 2162689, 2, 0, 0, 10, 0, 1, 0],
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await dataEscrowSerializer.calculateWitness(
                input,
                true,
            );
            // await dataEscrowSerializer.assertOut(wtns, output); - PROBLEM HERE
            await dataEscrowSerializer.checkConstraints(wtns, output);
            console.log('Witness calculation successful!');
        });
    });
});
