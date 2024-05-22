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

import {
    generateRandom256Bits,
    moduloBabyJubSubFieldPrime,
} from '@panther-core/crypto/lib/base/field-operations';
import poseidon from 'circomlibjs/src/poseidon';

describe('EphemeralPubKeysBuilder circuit', function (this: any) {
    let ephemeralPubKeysBuilder: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/ephemeralPubKeysBuilder.circom',
        );
        ephemeralPubKeysBuilder = await wasm_tester(input, opts);
    });

    let ephemeralRandom0, pubKey;
    /* START - EpheremalRandom-0 and  ephemeralPubKey-0 */
    // console.log('===== START - EpheremalRandom-0 and  ephemeralPubKey-0 =====');
    // Taking this value to be in sync with the integration tests
    ephemeralRandom0 =
        2508770261742365048726528579942226801565607871885423400214068953869627805520n;
    const ephemeralRandoms: bigint[] = [ephemeralRandom0];
    // console.log('ephemeralRandoms=>', ephemeralRandoms);

    // derive the first set of ephemeralPubKeys from first ephemeralRandom
    const ephemeralPubKey0 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom0,
    );
    const ephemeralPubKey: bigint[][] = [
        [ephemeralPubKey0[0], ephemeralPubKey0[1]],
    ];
    // console.log('ephemeralPubKey0=>', ephemeralPubKey0);
    // console.log('===== END - EpheremalRandom-0 and  ephemeralPubKey-0 =====');
    /* END - EpheremalRandom-0 and  ephemeralPubKey-0 */

    /* START - EpheremalRandom-1 and  ephemeralPubKey-1 */
    // console.log('===== START - EpheremalRandom-1 and  ephemeralPubKey-1 =====');
    // Generate ephemeralRandoms[1]
    const ephemeralRandoms1 = poseidon([
        ephemeralPubKey0[0],
        ephemeralPubKey0[1],
    ]);
    // console.log("Actual poseidon hash=>",ephemeralRandoms1);

    const finalEphemeralRandoms1 = ephemeralRandoms1 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms1=>', finalEphemeralRandoms1);
    ephemeralRandoms.push(finalEphemeralRandoms1);

    const ephemeralPubKey1 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms1,
    );
    // console.log('ephemeralPubKey1=>', ephemeralPubKey1);
    ephemeralPubKey.push([ephemeralPubKey1[0], ephemeralPubKey1[1]]);

    // console.log('ephemeralPubKey=>', ephemeralPubKey, ephemeralPubKey.length);
    // console.log('===== END - EpheremalRandom-1 and  ephemeralPubKey-1 =====');
    /* END - EpheremalRandom-1 and  ephemeralPubKey-1 */

    /* START - EpheremalRandom-2 and  ephemeralPubKey-2 */
    // console.log('===== START - EpheremalRandom-2 and  ephemeralPubKey-2 =====');
    // Generate ephemeralRandoms[2]
    const ephemeralRandoms2 = poseidon([
        ephemeralPubKey1[0],
        ephemeralPubKey1[1],
    ]);

    const finalEphemeralRandoms2 = ephemeralRandoms2 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms2=>', finalEphemeralRandoms2);
    ephemeralRandoms.push(finalEphemeralRandoms2);

    const ephemeralPubKey2 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms2,
    );
    // console.log('ephemeralPubKey2=>', ephemeralPubKey2);
    ephemeralPubKey.push([ephemeralPubKey2[0], ephemeralPubKey2[1]]);

    // console.log('===== END - EpheremalRandom-2 and  ephemeralPubKey-2 =====');
    /* END - EpheremalRandom-2 and  ephemeralPubKey-2 */

    /* START - EpheremalRandom-3 and  ephemeralPubKey-3 */
    // console.log('===== START - EpheremalRandom-3 and  ephemeralPubKey-3 =====');
    // Generate ephemeralRandoms[3]
    const ephemeralRandoms3 = poseidon([
        ephemeralPubKey2[0],
        ephemeralPubKey2[1],
    ]);

    const finalEphemeralRandoms3 = ephemeralRandoms3 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms3=>', finalEphemeralRandoms3);
    ephemeralRandoms.push(finalEphemeralRandoms3);

    const ephemeralPubKey3 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms3,
    );
    // console.log('ephemeralPubKey3=>', ephemeralPubKey3);
    ephemeralPubKey.push([ephemeralPubKey3[0], ephemeralPubKey3[1]]);

    // console.log('===== END - EpheremalRandom-3 and  ephemeralPubKey-3 =====');
    /* END - EpheremalRandom-3 and  ephemeralPubKey-3 */

    /* START - EpheremalRandom-4 and  ephemeralPubKey-4 */
    // console.log('===== START - EpheremalRandom-4 and  ephemeralPubKey-4 =====');
    // Generate ephemeralRandoms[4]
    const ephemeralRandoms4 = poseidon([
        ephemeralPubKey3[0],
        ephemeralPubKey3[1],
    ]);

    const finalEphemeralRandoms4 = ephemeralRandoms4 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms4=>', finalEphemeralRandoms4);
    ephemeralRandoms.push(finalEphemeralRandoms4);

    const ephemeralPubKey4 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms4,
    );
    // console.log('ephemeralPubKey4=>', ephemeralPubKey4);
    ephemeralPubKey.push([ephemeralPubKey4[0], ephemeralPubKey4[1]]);

    // console.log('===== END - EpheremalRandom-4 and  ephemeralPubKey-4 =====');
    /* END - EpheremalRandom-4 and  ephemeralPubKey-4 */

    /* START - EpheremalRandom-5 and  ephemeralPubKey-5 */
    // console.log('===== START - EpheremalRandom-5 and  ephemeralPubKey-5 =====');
    // Generate ephemeralRandoms[5]
    const ephemeralRandoms5 = poseidon([
        ephemeralPubKey4[0],
        ephemeralPubKey4[1],
    ]);

    const finalEphemeralRandoms5 = ephemeralRandoms5 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms5=>', finalEphemeralRandoms5);
    ephemeralRandoms.push(finalEphemeralRandoms5);

    const ephemeralPubKey5 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms5,
    );
    // console.log('ephemeralPubKey5=>', ephemeralPubKey5);
    ephemeralPubKey.push([ephemeralPubKey5[0], ephemeralPubKey5[1]]);

    // console.log('===== END - EpheremalRandom-4 and  ephemeralPubKey-4 =====');
    /* END - EpheremalRandom-5 and  ephemeralPubKey-5 */

    /* START - EpheremalRandom-6 and  ephemeralPubKey-6 */
    // console.log('===== START - EpheremalRandom-6 and  ephemeralPubKey-6 =====');
    // Generate ephemeralRandoms[6]
    const ephemeralRandoms6 = poseidon([
        ephemeralPubKey5[0],
        ephemeralPubKey5[1],
    ]);

    const finalEphemeralRandoms6 = ephemeralRandoms6 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms6=>', finalEphemeralRandoms6);
    ephemeralRandoms.push(finalEphemeralRandoms6);

    const ephemeralPubKey6 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms6,
    );
    // console.log('ephemeralPubKey6=>', ephemeralPubKey6);
    ephemeralPubKey.push([ephemeralPubKey6[0], ephemeralPubKey6[1]]);

    // console.log('===== END - EpheremalRandom-6 and  ephemeralPubKey-6 =====');
    /* END - EpheremalRandom-6 and  ephemeralPubKey-6 */

    /* START - EpheremalRandom-7 and  ephemeralPubKey-7 */
    // console.log('===== START - EpheremalRandom-7 and  ephemeralPubKey-7 =====');
    // Generate ephemeralRandoms[7]
    const ephemeralRandoms7 = poseidon([
        ephemeralPubKey6[0],
        ephemeralPubKey6[1],
    ]);

    const finalEphemeralRandoms7 = ephemeralRandoms7 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms7=>', finalEphemeralRandoms7);
    ephemeralRandoms.push(finalEphemeralRandoms7);

    const ephemeralPubKey7 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms7,
    );
    // console.log('ephemeralPubKey7=>', ephemeralPubKey7);
    ephemeralPubKey.push([ephemeralPubKey7[0], ephemeralPubKey7[1]]);
    // console.log('===== END - EpheremalRandom-7 and  ephemeralPubKey-7 =====');
    /* END - EpheremalRandom-7 and  ephemeralPubKey-7 */

    /* START - EpheremalRandom-8 and  ephemeralPubKey-8 */
    // console.log('===== START - EpheremalRandom-8 and  ephemeralPubKey-8 =====');
    // Generate ephemeralRandoms[8]
    const ephemeralRandoms8 = poseidon([
        ephemeralPubKey7[0],
        ephemeralPubKey7[1],
    ]);

    const finalEphemeralRandoms8 = ephemeralRandoms8 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms8=>', finalEphemeralRandoms8);
    ephemeralRandoms.push(finalEphemeralRandoms8);

    const ephemeralPubKey8 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms8,
    );
    // console.log('ephemeralPubKey8=>', ephemeralPubKey8);
    ephemeralPubKey.push([ephemeralPubKey8[0], ephemeralPubKey8[1]]);
    // console.log('===== END - EpheremalRandom-8 and  ephemeralPubKey-8 =====');
    /* END - EpheremalRandom-8 and  ephemeralPubKey-8 */

    /* START - EpheremalRandom-9 and  ephemeralPubKey-9 */
    // console.log('===== START - EpheremalRandom-9 and  ephemeralPubKey-9 =====');
    // Generate ephemeralRandoms[9]
    const ephemeralRandoms9 = poseidon([
        ephemeralPubKey8[0],
        ephemeralPubKey8[1],
    ]);

    const finalEphemeralRandoms9 = ephemeralRandoms9 & ((1n << 252n) - 1n);
    // console.log('finalEphemeralRandoms9=>', finalEphemeralRandoms9);
    ephemeralRandoms.push(finalEphemeralRandoms9);

    const ephemeralPubKey9 = babyjub.mulPointEscalar(
        babyjub.Base8,
        finalEphemeralRandoms9,
    );
    // console.log('ephemeralPubKey9=>', ephemeralPubKey9);
    ephemeralPubKey.push([ephemeralPubKey9[0], ephemeralPubKey9[1]]);
    // console.log('===== END - EpheremalRandom-9 and  ephemeralPubKey-9 =====');
    /* END - EpheremalRandom-9 and  ephemeralPubKey-9 */

    /* ephemeralRandom * pubKey - work in progress */
    const ephemeralRandomPubKey: bigint[][] = [];

    for (let i = 0; i < 10; i++) {
        const ephemeralRandomPubKeyGen = babyjub.mulPointEscalar(
            [
                6461944716578528228684977568060282675957977975225218900939908264185798821478n,
                6315516704806822012759516718356378665240592543978605015143731597167737293922n,
            ],
            ephemeralRandoms[i],
        );
        ephemeralRandomPubKey.push(ephemeralRandomPubKeyGen);
    }
    // console.log('ephemeralRandomPubKey=>', ephemeralRandomPubKey);

    const input = {
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n,
    };

    const output = {
        ephemeralRandoms: ephemeralRandoms,
        ephemeralPubKey: ephemeralPubKey,
        ephemeralRandomPubKey: ephemeralRandomPubKey,
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await ephemeralPubKeysBuilder.calculateWitness(
                input,
                true,
            );
            await ephemeralPubKeysBuilder.assertOut(wtns, output);
            console.log('Witness calculation successful!');
        });
    });
});
