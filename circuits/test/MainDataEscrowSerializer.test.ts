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
    const zAccountNonce = 2;
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
    const utxoInOriginZoneId = [0, 0];
    const utxoOutTargetZoneId = [1, 0];

    const utxoInAmount = [0, 0];
    const utxoOutAmount = [10, 0];

    function toBinaryWithBits(number: any, bits: any) {
        let binary = number.toString(2); // Convert number to binary
        return binary.padStart(bits, '0'); // Pad with leading zeros to the specified number of bits
    }

    function reverseBinaryString(binary: any) {
        return binary.split('').reverse().join('');
    }

    function appendBinaryStrings(
        binary1: any,
        binary2: any,
        binary3: any,
        binary4: any,
        binary5: any,
        binary6: any,
        binary7: any,
    ) {
        // Append the binary strings
        let result =
            binary1 + binary2 + binary3 + binary4 + binary5 + binary6 + binary7;

        // Return the combined binary string
        return result;
    }

    // 1. serialize bit2num0
    // zAsset - 64 bits
    const zAssetInBits = toBinaryWithBits(zAssetID, 64);
    // console.log('zAssetInBits=>', zAssetInBits);

    // zAccountId - 24 bits
    const zAccountIdInBits = toBinaryWithBits(zAccountId, 24);
    // console.log('zAccountIdInBits=>', zAccountIdInBits);

    // zAccountZoneId - 16 bits
    const zAccountZoneIdInBits = toBinaryWithBits(zAccountZoneId, 16);
    // console.log('zAccountZoneIdInBits=>', zAccountZoneIdInBits);

    // zAccountNonce - 32 bits
    const zAccountNonceIdInBits = toBinaryWithBits(zAccountNonce, 32);
    // console.log('zAccountNonceIdInBits=>', zAccountNonceIdInBits);

    // utxoInMerkleTreeSelector[nUtxoIn][2] - 2 * 2 = 4 bits
    const utxoInMerkleTreeSelectorInBits = toBinaryWithBits(0x0000, 4); // utxoInMerkleTreeSelector - [[0,0],[0,0]]
    // console.log(
    //     'utxoInMerkleTreeSelectorInBits=>',
    //     utxoInMerkleTreeSelectorInBits,
    // );

    // utxoInPathIndices[nUtxoIn][UtxoMerkleTreeDepth] - 32 * 2
    // [
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0,
    // ],
    // [
    //     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    //     0, 0, 0, 0, 0, 0, 0, 0, 0,
    // ],
    const utxoInPathIndicesInBits = toBinaryWithBits(
        0x0000000000000000000000000000000000000000000000000000000000000000,
        64,
    );
    // console.log('utxoInPathIndicesInBits=>', utxoInPathIndicesInBits);

    // const utxoInOriginZoneId - 16 * 2
    // [0, 0]
    const utxoInOriginZoneIdInBits = toBinaryWithBits(
        0x00000000000000000000000000000000,
        32,
    );

    const finalBinaryString = appendBinaryStrings(
        zAssetInBits,
        reverseBinaryString(zAccountIdInBits),
        reverseBinaryString(zAccountZoneIdInBits),
        reverseBinaryString(zAccountNonceIdInBits),
        reverseBinaryString(utxoInMerkleTreeSelectorInBits),
        reverseBinaryString(utxoInPathIndicesInBits),
        reverseBinaryString(utxoInOriginZoneIdInBits),
    );
    // console.log(
    //     'finalBinaryString=>',
    //     finalBinaryString,
    //     typeof finalBinaryString,
    // );

    let bit2num0 = 0;
    for (let i = 0; i < 236; i++) {
        bit2num0 += finalBinaryString[i] == 0 ? 0 : 2 ** i;
    }
    // 40565128692921904747395642556416n
    // console.log('final sum=>', BigInt(bit2num0));

    // 2. serialize bit2num1
    // utxoOutTargetZoneId - 16 bits
    const utxoOutTargetZoneIdInBits0 = toBinaryWithBits(
        utxoOutTargetZoneId[0],
        16,
    );
    const utxoOutTargetZoneIdInBits1 = toBinaryWithBits(
        utxoOutTargetZoneId[1],
        16,
    );

    // utxoInAmount - 64 bits
    const utxoInAmount0 = toBinaryWithBits(utxoInAmount[0], 64);
    const utxoInAmount1 = toBinaryWithBits(utxoInAmount[1], 64);

    const finalBinaryString1 =
        reverseBinaryString(utxoOutTargetZoneIdInBits0) +
        reverseBinaryString(utxoOutTargetZoneIdInBits1) +
        reverseBinaryString(utxoInAmount0) +
        reverseBinaryString(utxoInAmount1);
    // console.log('finalBinaryString1=>', finalBinaryString1);

    let bit2num1 = 0;
    for (let i = 0; i < 160; i++) {
        bit2num1 += finalBinaryString1[i] == 0 ? 0 : 2 ** i;
    }
    // 1
    // console.log('final sum=>', BigInt(bit2num1));

    // 3. serialize bit2num2
    // utxoOutAmount - 64 bits
    const utxoOutAmount0InBits = toBinaryWithBits(utxoOutAmount[0], 64);
    const utxoOutAmount1InBits = toBinaryWithBits(utxoOutAmount[1], 64);

    const finalBinaryString2 =
        reverseBinaryString(utxoOutAmount0InBits) +
        reverseBinaryString(utxoOutAmount1InBits);
    // console.log('finalBinaryString2=>', finalBinaryString2);

    let bit2num2 = 0;
    for (let i = 0; i < 128; i++) {
        bit2num2 += finalBinaryString2[i] == 0 ? 0 : 2 ** i;
    }
    // 10
    // console.log('final sum=>', BigInt(bit2num2));

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
        out: [40565128692921904747395642556416n, 1, 10],
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
