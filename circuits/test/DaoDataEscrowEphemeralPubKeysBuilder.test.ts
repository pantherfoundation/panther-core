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
    const hiddenPoint_poseidon1 = poseidon([
        sharedPubKey0[0],
        sharedPubKey0[1],
    ]);
    const hiddenPoint_poseidon = poseidon([hiddenPoint_poseidon1]);
    let mask = (BigInt(1) << BigInt(252)) - BigInt(1);
    let hiddenPoint252Bits = BigInt(hiddenPoint_poseidon) & mask;

    const hiddenPoint_eMult = babyjub.mulPointEscalar(
        pubKey,
        hiddenPoint252Bits,
    );
    // hiddenPoint_eMult=> [
    //     21766969157293173109696548600547868329008480468314353375481116030202645714574n,
    //     14170566993523714956664006432117637614208911899318146403393618728345804921043n
    //   ]
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
            21766969157293173109696548600547868329008480468314353375481116030202645714574n,
            14170566993523714956664006432117637614208911899318146403393618728345804921043n,
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
