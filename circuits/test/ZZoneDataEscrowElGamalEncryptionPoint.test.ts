import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';

describe('ZZone Data Escrow ElGamal Encryption', function (this: any) {
    let zZoneDataEscrowElGamalEncryption: any;
    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/zZoneDataEscrowElGamalEncryptionPointMain.circom',
        );
        zZoneDataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    const zZoneDataEscrowEphemeralRandom =
        790122152066676684676093302872898287841903882354339429497975929636832086290n;

    const zZoneEdDsaPubKey = [
        13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        11069452135192839850369824221357904553346382352990372044246668947825855305207n,
    ];

    const pointMessage = [
        [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
    ];

    const sharedPubKey0 = [
        [
            3579452621007862409166467823704846427808645445097270817162531245395116740794n,
            21104711759309908609089048597965635688447821050509879948755813223129622499159n,
        ],
    ];

    const encryptedMessage0 = babyjub.addPoint(
        pointMessage[0],
        sharedPubKey0[0],
    );
    // console.log('encryptedMessage0=>', encryptedMessage0);

    const input = {
        ephemeralRandom: zZoneDataEscrowEphemeralRandom,
        pointMessage: pointMessage,
        pubKey: zZoneEdDsaPubKey,
    };

    const output = {
        ephemeralPubKey: [
            8203289148254703516772267706874329469330087297928457772489392227653451244213n,
            19998992060707539017877331634603765261877243592349009808298088607668947098216n,
        ],
        encryptedMessage: [
            [
                2468338014121331792444587249698692818014762050360212301429643474146750905863n,
                16996420608431036321409292371827871642706083345802290766905570404093710249010n,
            ],
        ],
    };
    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns =
                await zZoneDataEscrowElGamalEncryption.calculateWitness(
                    input,
                    true,
                );

            const indexOfephemeralPubKey0 = wtns.indexOf(
                output.ephemeralPubKey[0],
            );
            const indexOfephemeralPubKey1 = wtns.indexOf(
                output.ephemeralPubKey[1],
            );
            const indexOfencryptedMessage00 = wtns.indexOf(
                output.encryptedMessage[0][0],
            );
            const indexOfencryptedMessage01 = wtns.indexOf(
                output.encryptedMessage[0][1],
            );

            const wtnsFormattedOutput = [
                0,
                wtns[indexOfephemeralPubKey0],
                wtns[indexOfephemeralPubKey1],
                wtns[indexOfencryptedMessage00],
                wtns[indexOfencryptedMessage01],
            ];

            await zZoneDataEscrowElGamalEncryption.assertOut(
                wtnsFormattedOutput,
                output,
            );

            console.log('Witness calculation successful!');
        });
    });
});
