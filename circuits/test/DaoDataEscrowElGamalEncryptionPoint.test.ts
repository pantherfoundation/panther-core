import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';

describe('DAO Data Escrow ElGamalEncryption', function (this: any) {
    let daoDataEscrowElGamalEncryption: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/daoDataEscrowElGamalEncryptionPointMain.circom',
        );
        daoDataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    const daoDataEscrowEphemeralRandom =
        2486295975768183987242341265649589729082265459252889119245150374183802141273n;

    const pointMessage = [
        [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
    ];
    const daoDataEscrowPubKey = [
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    ];
    const sharedPubKey0 = [
        [
            13715319542819033053725524764668495039205583207727432604755257637044067035829n,
            11581561341765082553491028981889175415385375492244621840510004970440934456100n,
        ],
    ];

    const encryptedMessage0 = babyjub.addPoint(
        pointMessage[0],
        sharedPubKey0[0],
    );
    // console.log('encryptedMessage0=>', encryptedMessage0);

    const input = {
        ephemeralRandom: daoDataEscrowEphemeralRandom,
        pointMessage: pointMessage,
        pubKey: daoDataEscrowPubKey,
    };

    const output = {
        ephemeralPubKey: [
            18172727478723733672122242648004425580927771110712257632781054272274332874233n,
            18696859439217809465524370245449396885627295546811556940609392448191776076084n,
        ],
        encryptedMessage: [
            [
                12032028674386602247606112047856619939984457257499437643949614462266665472292n,
                10231473684893412031634651500584679273869045480560969585260750474375209497228n,
            ],
        ],
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await daoDataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[261],
                wtns[262],
                wtns[263],
                wtns[264],
            ];

            await daoDataEscrowElGamalEncryption.assertOut(
                wtnsFormattedOutput,
                output,
            );

            console.log('Witness calculation successful!');
        });
    });
});
