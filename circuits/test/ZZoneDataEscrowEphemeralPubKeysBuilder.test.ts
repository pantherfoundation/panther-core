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
    //     3285643778013373851751435147704859609182820956390679408406396837095210775191n,
    //     19488993062119338329039070493533050536743750381173930389742335045938707033749n
    //   ]
    // console.log('hiddenPoint_eMult=>', hiddenPoint_eMult);

    const input = {
        pubKey: [
            13969057660566717294144404716327056489877917779406382026042873403164748884885n,
            11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        ],
        ephemeralRandom:
            790122152066676684676093302872898287841903882354339429497975929636832086290n,
    };

    const output = {
        ephemeralPubKey: [
            [
                8203289148254703516772267706874329469330087297928457772489392227653451244213n,
                19998992060707539017877331634603765261877243592349009808298088607668947098216n,
            ],
        ],
        sharedPubKey: [
            [
                3579452621007862409166467823704846427808645445097270817162531245395116740794n,
                21104711759309908609089048597965635688447821050509879948755813223129622499159n,
            ],
        ],
        hidingPoint: [
            3285643778013373851751435147704859609182820956390679408406396837095210775191n,
            19488993062119338329039070493533050536743750381173930389742335045938707033749n,
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
