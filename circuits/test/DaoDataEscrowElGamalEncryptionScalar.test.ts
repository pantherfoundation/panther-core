import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';
import {generateRandomKeypair} from '@panther-core/crypto/lib/base/keypairs';
import {getRandomInt} from './helpers/utility';
import {generateRandomInBabyJubSubField} from '@panther-core/crypto/lib/base/field-operations';
import {Scalar} from 'ffjavascript';
const {shiftLeft} = Scalar;
const {bor} = Scalar;

describe('DaoDataEscrowElGamalEncryptionScalar circuit', function (this: any) {
    let dataEscrowElGamalEncryption: any;
    // Use timeout if needed
    this.timeout(10000000);

    // Info: Executed once before all the test cases
    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/daoDataEscrowElGamalEncryptionScalar.circom',
        );
        dataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    // Info: Executed before each test cases
    beforeEach(async function () {
        // TODO: Declare all the variables that needs to be initialised for each test cases
    });

    /*******************************************************************************************************************
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// component main = DaoDataEscrowElGamalEncryptionScalar(3); ////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        1) 3 - scalar size
            ----- 3 for 4 x 64 bit values -----
            signal input zAccountId;                      // 24 bit
            signal input zAccountZoneId;                  // 16 bit
            signal input utxoInOriginZoneId[nUtxoIn=2];   // 16 bit
            signal input utxoOutTargetZoneId[nUtxoOut=2]; // 16 bit

            1 - zAccountID (24 bit) << 16 | zAccountZoneId (16 bit)
            2 - utxoInOriginZoneId-1 (16 bit) << 16 | utxoOutTargetZoneId-1 (16 bit)
            3 - utxoInOriginZoneId-2 (16 bit) << 16 | utxoOutTargetZoneId-2 (16 bit)
            -----------------------------------
        2) ephimeralRandom, ephimeralPubKey[x,y], pubKey[x,y]
           2.1) ephimeralPubKey[x,y] == ephimeralRandom * G
           2.2) pubKey[x,y] - pubKey that its inclusion is proven
        3) encryptedMessage[2][x,y] - encrypted points
            3.1) ephimeralRandomPubKey[x,y] = pubKey[x,y] * ephimeralRandom
            3.2) Encrypt scalars:
                3.2.1) scalar mapping: M_scalar_points = m_scalar * G for each scalar out of 8
                    --> M_scalar_points[8][x,y]
                3.2.2) elgamal: encryptedscalars[8][x,y] = M_scalar_points[8][x,y] + ephimeralRandomPubKey[x,y]
        4) Encrypted Output
            4.1) encyptedMessage[0-to-1][x,y] = encryptedscalars[2][x,y]
     ******************************************************************************************************************/
    ////////////////////////////////////////
    // Semi contrants values ///////////////
    ////////////////////////////////////////
    let dataEscrowKeyPair = generateRandomKeypair(); // taken from the merkle-tree
    let zAccountID = BigInt(getRandomInt(0, 2 ** 24)); //  each zAssount has it
    let zAccountZoneID = BigInt(getRandomInt(0, 2 ** 16)); //  each zAssount has it
    let utxoInOriginZoneIds = [
        BigInt(getRandomInt(0, 2 ** 16)),
        BigInt(getRandomInt(0, 2 ** 16)),
    ];
    let utxoOutTargetZoneIds = [
        BigInt(getRandomInt(0, 2 ** 16)),
        BigInt(getRandomInt(0, 2 ** 16)),
    ];

    let ephimeralRandom = generateRandomInBabyJubSubField();
    let ephimeralPubKey = [
        BigInt(babyjub.mulPointEscalar(babyjub.Base8, ephimeralRandom)[0]),
        BigInt(babyjub.mulPointEscalar(babyjub.Base8, ephimeralRandom)[1]),
    ];
    let ephimeralRandomPubKey = [
        BigInt(
            babyjub.mulPointEscalar(
                dataEscrowKeyPair.publicKey,
                ephimeralRandom,
            )[0],
        ),
        BigInt(
            babyjub.mulPointEscalar(
                dataEscrowKeyPair.publicKey,
                ephimeralRandom,
            )[1],
        ),
    ];

    // [0] - scalars serialization
    let m_scalar = [
        BigInt(bor(shiftLeft(zAccountID, 16),zAccountZoneID).toString()),
        BigInt(
            bor(shiftLeft(utxoInOriginZoneIds[0], 16),
                utxoOutTargetZoneIds[0])
                .toString()
        ),
        BigInt(
            bor(shiftLeft(utxoInOriginZoneIds[1], 16),
                utxoOutTargetZoneIds[1])
                .toString()
        ),
    ];
    // [1] = scalars to Points mapping
    let M_scalar_points = [
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[0]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[1]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[2]),
    ];
    // [2] - elgamal scalars + points
    let enctyptedMessage = [
        // scalars
        babyjub.addPoint(M_scalar_points[0], ephimeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[1], ephimeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[2], ephimeralRandomPubKey),
    ];

    const input = {
        ephimeralRandom: ephimeralRandom,
        scalarMessage: m_scalar,
        pubKey: dataEscrowKeyPair.publicKey,
    };

    const output = {
        ephimeralPubKey: ephimeralPubKey,
        encryptedMessage: [
            [
                BigInt(enctyptedMessage[0][0]),
                BigInt(enctyptedMessage[0][1]),
            ],
            [
                BigInt(enctyptedMessage[1][0]),
                BigInt(enctyptedMessage[1][1]),
            ],
        ],
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await dataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );
            await dataEscrowElGamalEncryption.assertOut(wtns, output);
            console.log('Witness calculation successful!');
        });
    });
});
