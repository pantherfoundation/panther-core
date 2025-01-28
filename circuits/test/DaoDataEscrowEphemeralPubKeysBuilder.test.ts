import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

describe('DAO DataEscrow - EphemeralPubKeysBuilder circuit', function (this: any) {
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

    const ephemeralRandom =
        2486295975768183987242341265649589729082265459252889119245150374183802141273n;

    const pubKey = [
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    ];

    const sharedPubKey = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom.toString(),
    );
    // console.log('sharedPubKey=>', sharedPubKey);

    const ephemeralPubKey = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom,
    );
    // console.log('ephemeralPubKey=>', ephemeralPubKey);

    const input = {
        pubKey: [
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ],
        ephemeralRandom:
            2486295975768183987242341265649589729082265459252889119245150374183802141273n,
    };

    const output = {
        ephemeralPubKey: [ephemeralPubKey[0], ephemeralPubKey[1]],
        sharedPubKey: [sharedPubKey[0], sharedPubKey[1]],
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
