import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

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

    const ephemeralRandom =
        2486295975768183987242341265649589729082265459252889119245150374183802141273n;

    const pubKey = [
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    ];

    // ephemeralRandom0 is the given input ephemeralRandom - 0

    // sharedPubKey0 - [0,0] & [0,1]
    const sharedPubKey0 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom.toString(),
    );
    // console.log('sharedPubKey0=>', sharedPubKey0);

    // ephemeralPubKey0 - [0,0] & [0,1]
    const ephemeralPubKey0 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom,
    );
    // console.log('ephemeralPubKey0=>', ephemeralPubKey0);

    // hidden point computation
    const hiddenPoint_poseidon_out = poseidon([
        sharedPubKey0[0],
        sharedPubKey0[1],
    ]);

    let mask = (BigInt(1) << BigInt(252)) - BigInt(1);
    let hiddenPoint252Bits = BigInt(hiddenPoint_poseidon_out) & mask;

    const hiddenPoint_eMult = babyjub.mulPointEscalar(
        pubKey,
        hiddenPoint252Bits,
    );
    // console.log('hiddenPoint_eMult=>', hiddenPoint_eMult);

    const input = {
        pubKey: [
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ],
        ephemeralRandom:
            2486295975768183987242341265649589729082265459252889119245150374183802141273n,
    };

    const output = {
        ephemeralPubKey: [
            [
                18172727478723733672122242648004425580927771110712257632781054272274332874233n,
                18696859439217809465524370245449396885627295546811556940609392448191776076084n,
            ],
        ],
        sharedPubKey: [
            [
                13715319542819033053725524764668495039205583207727432604755257637044067035829n,
                11581561341765082553491028981889175415385375492244621840510004970440934456100n,
            ],
        ],
        hidingPoint: [
            7837537477801095879520439572942173219514831830643764560925331456186676726807n,
            19073186060657841909220319139802990623418587721671395108608781299288560825063n,
        ],
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
