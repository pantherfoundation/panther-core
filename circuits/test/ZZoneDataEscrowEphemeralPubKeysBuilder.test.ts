import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

describe('ZZone DataEscrow - EphemeralPubKeysBuilder circuit', function (this: any) {
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
        790122152066676684676093302872898287841903882354339429497975929636832086290n;

    const pubKey = [
        13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        11069452135192839850369824221357904553346382352990372044246668947825855305207n,
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
            13969057660566717294144404716327056489877917779406382026042873403164748884885n,
            11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        ],
        ephemeralRandom:
            790122152066676684676093302872898287841903882354339429497975929636832086290n,
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
