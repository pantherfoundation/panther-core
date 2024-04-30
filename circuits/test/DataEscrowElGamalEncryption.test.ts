import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';
import {generateRandomKeypair} from '@panther-core/crypto/lib/base/keypairs';
import {getRandomInt} from './helpers/utility';
import {
    generateRandom256Bits,
    generateRandomInBabyJubSubField,
} from '@panther-core/crypto/lib/base/field-operations';
import {Scalar} from 'ffjavascript';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';
const {shiftLeft} = Scalar;
const {bor} = Scalar;
describe('DataEscrowElGamalEncryption circuit', function (this: any) {
    let dataEscrowElGamalEncryption: any;
    // Use timeout if needed
    this.timeout(10000000);

    // Info: Executed once before all the test cases
    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/dataEscrowElGamalEncryption.circom',
        );
        dataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    // Info: Executed before each test cases
    beforeEach(async function () {
        // TODO: Declare all the variables that needs to be initialised for each test cases
    });

    /*******************************************************************************************************************
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// component main = DataEscrowElGamalEncryption(8-scalars,2-Points); ///////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        1) 8 - scalar size, 2 point size (Please refer to DataEscrowSerializer code)
            ----- 2 for 2 x Point(x,y) ------
            1 - utxoOut-1-RootPubKey[x,y]
            2 - utxoOut-2-RootPubKey[x,y]
            -----------------------------------
            ----- 8 for 8 x 64 bit values -----
            signal input zAsset;                          // 64 bit
            signal input zAccountId;                      // 24 bit
            signal input zAccountZoneId;                  // 16 bit

            signal input utxoInAmount[nUtxoIn=2];         // 64 bit
            signal input utxoOutAmount[nUtxoOut=2];       // 64 bit

            signal input utxoInOriginZoneId[nUtxoIn=2];   // 16 bit
            signal input utxoOutTargetZoneId[nUtxoOut=2]; // 16 bit

            1 - zAsset (32 bit)
            2 - zAccountID (24 bit) << 16 | zAccountZoneId (16 bit)
            3 - utxoInAmount-1 (64 bit)
            4 - utxoInAmount-2 (64 bit)
            5 - utxoOutAmount-1 (64 bit)
            6 - utxoOutAmount-2 (64 bit)
            7 - utxoInOriginZoneId-1 (16 bit) << 16 | utxoOutTargetZoneId-1 (16 bit)
            8 - utxoInOriginZoneId-2 (16 bit) << 16 | utxoOutTargetZoneId-2 (16 bit)
            -----------------------------------
        2) ephemeralRandom, ephemeralPubKey[x,y], pubKey[x,y]
           2.1) ephemeralPubKey[x,y] == ephemeralRandom * G
           2.2) pubKey[x,y] - pubKey that its inclusion is proven
        3) encryptedMessage[8(scalars)+2(points)][x,y] - encrypted points
            3.1) ephemeralRandomPubKey[x,y] = pubKey[x,y] * ephemeralRandom
            3.2) Encrypt scalars:
                3.2.1) scalar mapping: M_scalar_points = m_scalar * G for each scalar out of 8
                    --> M_scalar_points[8][x,y]
                3.2.2) elgamal: encryptedscalars[8][x,y] = M_scalar_points[8][x,y] + ephemeralRandomPubKey[x,y]
            3.3) Encrypt Points:
                3.3.1) elgamal: encyptedPoints[2][x,y] = M_points[2][x,y] + ephemeralRandomPubKey[x,y]
        4) Encrypted Output
            4.1) encyptedMessage[0-to-7][x,y] = encryptedscalars[8][x,y]
            4.2) encyptedMessage[8-to-9][x,y] = encryptedPoints[8][x,y]
     ******************************************************************************************************************/
    ////////////////////////////////////////
    // Semi contrants values ///////////////
    ////////////////////////////////////////
    let dataEscrowKeyPair = generateRandomKeypair(); // taken from the merkle-tree
    let utxoOutRootKeyPairs = [
        generateRandomKeypair(),
        generateRandomKeypair(),
    ]; // each zAssount has it
    let zAccountID = BigInt(getRandomInt(0, 2 ** 24)); //  each zAssount has it
    let zAccountZoneID = BigInt(getRandomInt(0, 2 ** 16)); //  each zAssount has it

    ////////////////////////////////////////
    // Transaction values //////////////////
    ////////////////////////////////////////
    let zAssetID = BigInt(getRandomInt(0, 2 ** 32)); // each zAsset has it
    let utxoInAmounts = [
        BigInt(getRandomInt(0, 2 ** 64)),
        BigInt(getRandomInt(0, 2 ** 64)),
    ];
    let utxoOutAmounts = [
        BigInt(getRandomInt(0, 2 ** 64)),
        BigInt(getRandomInt(0, 2 ** 64)),
    ];
    let utxoInOriginZoneIds = [
        BigInt(getRandomInt(0, 2 ** 16)),
        BigInt(getRandomInt(0, 2 ** 16)),
    ];
    let utxoOutTargetZoneIds = [
        BigInt(getRandomInt(0, 2 ** 16)),
        BigInt(getRandomInt(0, 2 ** 16)),
    ];
    let ephemeralRandom = generateRandomInBabyJubSubField();
    let ephemeralPubKey = [
        BigInt(babyjub.mulPointEscalar(babyjub.Base8, ephemeralRandom)[0]),
        BigInt(babyjub.mulPointEscalar(babyjub.Base8, ephemeralRandom)[1]),
    ];
    let ephemeralRandomPubKey = [
        BigInt(
            babyjub.mulPointEscalar(
                dataEscrowKeyPair.publicKey,
                ephemeralRandom,
            )[0],
        ),
        BigInt(
            babyjub.mulPointEscalar(
                dataEscrowKeyPair.publicKey,
                ephemeralRandom,
            )[1],
        ),
    ];

    // [0] - scalars serialization
    let m_scalar = [
        zAssetID,
        BigInt(bor(shiftLeft(zAccountID, 16), zAccountZoneID).toString()),
        utxoInAmounts[0],
        utxoInAmounts[1],
        utxoOutAmounts[0],
        utxoOutAmounts[1],
        BigInt(
            bor(
                shiftLeft(utxoInOriginZoneIds[0], 16),
                utxoOutTargetZoneIds[0],
            ).toString(),
        ),
        BigInt(
            bor(
                shiftLeft(utxoInOriginZoneIds[1], 16),
                utxoOutTargetZoneIds[1],
            ).toString(),
        ),
    ];
    // [1] = scalars to Points mapping
    let M_scalar_points = [
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[0]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[1]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[2]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[3]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[4]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[5]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[6]),
        babyjub.mulPointEscalar(babyjub.Base8, m_scalar[7]),
    ];
    // [2] - Points
    let M_points = [
        utxoOutRootKeyPairs[0].publicKey,
        utxoOutRootKeyPairs[1].publicKey,
    ];
    // [3] - elgamal scalars + points
    let enctyptedMessage = [
        // scalars
        babyjub.addPoint(M_scalar_points[0], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[1], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[2], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[3], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[4], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[5], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[6], ephemeralRandomPubKey),
        babyjub.addPoint(M_scalar_points[7], ephemeralRandomPubKey),
        // points
        babyjub.addPoint(M_points[0], ephemeralRandomPubKey),
        babyjub.addPoint(M_points[1], ephemeralRandomPubKey),
    ];

    const input = {
        ephemeralRandom: ephemeralRandom,
        scalarMessage: m_scalar,
        pointMessage: M_points,
        pubKey: dataEscrowKeyPair.publicKey,
    };

    const output = {
        ephemeralPubKey: ephemeralPubKey,
        encryptedMessage: [
            [BigInt(enctyptedMessage[0][0]), BigInt(enctyptedMessage[0][1])],
            [BigInt(enctyptedMessage[1][0]), BigInt(enctyptedMessage[1][1])],
            [BigInt(enctyptedMessage[2][0]), BigInt(enctyptedMessage[2][1])],
            [BigInt(enctyptedMessage[3][0]), BigInt(enctyptedMessage[3][1])],
            [BigInt(enctyptedMessage[4][0]), BigInt(enctyptedMessage[4][1])],
            [BigInt(enctyptedMessage[5][0]), BigInt(enctyptedMessage[5][1])],
            [BigInt(enctyptedMessage[6][0]), BigInt(enctyptedMessage[6][1])],
            [BigInt(enctyptedMessage[7][0]), BigInt(enctyptedMessage[7][1])],
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
        it('should compute valid elgamal', async () => {
            let priv_key = generateRandomInBabyJubSubField();
            let pub_key = mulPointEscalar(babyjub.Base8, priv_key);
            let random = generateRandomInBabyJubSubField();
            let e_pub_key = mulPointEscalar(babyjub.Base8, random);
            let point = mulPointEscalar(
                babyjub.Base8,
                generateRandomInBabyJubSubField(),
            );
            let hidding = mulPointEscalar(pub_key, random);
            let enctypted_data = babyjub.addPoint(point, hidding);
            let unhidding = mulPointEscalar(e_pub_key, priv_key);
            let y_neg = BigInt(babyjub.p) - BigInt(unhidding[0]);
            let unhidding_neg = unhidding;
            unhidding_neg[0] = y_neg;
            let decrypted = babyjub.addPoint(enctypted_data, unhidding_neg);

            console.log('point {}, decrypted_point', point, decrypted);
            console.assert(
                point[0] == decrypted[0] && point[1] == decrypted[1],
                'point {}, decrypted_point',
                point,
                decrypted,
            );
        });
    });
});
