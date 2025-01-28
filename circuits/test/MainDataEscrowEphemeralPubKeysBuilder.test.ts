import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

describe('Main DataEscrow - EphemeralPubKeysBuilder circuit', function (this: any) {
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

    // Taking this value ephemeralRandom and pubKey to be in sync with the integration tests
    const ephemeralRandom =
        2508770261742365048726528579942226801565607871885423400214068953869627805520n;

    const pubKey = [
        6461944716578528228684977568060282675957977975225218900939908264185798821478n,
        6315516704806822012759516718356378665240592543978605015143731597167737293922n,
    ];

    const sharedPubKey = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom.toString(),
    );
    // sharedPubKey=> [
    //     12871439135712262058001002684440962908819002983015508623206745248194094676428n,
    //     17114886397516225242214463605558970802516242403903915116207133292790211059315n
    //   ]
    // console.log('sharedPubKey=>', sharedPubKey);

    const ephemeralPubKey = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom,
    );
    // ephemeralPubKey=> [
    //     4301916310975298895721162797900971043392040643140207582177965168853046592976n,
    //     815388028464849479935447593762613752978886104243152067307597626016673798528n
    //   ]
    // console.log('ephemeralPubKey=>', ephemeralPubKey);

    const input = {
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n,
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
