import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';
import poseidon from 'circomlibjs/src/poseidon';

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

    const SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617n;

    const daoDataEscrowEphemeralRandom =
        2486295975768183987242341265649589729082265459252889119245150374183802141273n;

    const daoDataEscrowPubKey = [
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    ];

    const pointMessage = [
        [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n, // dataEscrowEphemeralPubKeyAx
            815388028464849479935447593762613752978886104243152067307597626016673798528n, // dataEscrowEphemeralPubKeyAy
        ],
    ];

    // computation of `ephemeralPubKey` and `sharedPubKey` via EphemeralPubKeysBuilder
    const sharedPubKey = babyjub.mulPointEscalar(
        daoDataEscrowPubKey,
        daoDataEscrowEphemeralRandom.toString(),
    );
    // sharedPubKey=> [
    //     13715319542819033053725524764668495039205583207727432604755257637044067035829n,
    //     11581561341765082553491028981889175415385375492244621840510004970440934456100n
    //   ]
    // console.log('sharedPubKey=>', sharedPubKey);

    const ephemeralPubKey = babyjub.mulPointEscalar(
        babyjub.Base8,
        daoDataEscrowEphemeralRandom,
    );
    // ephemeralPubKey=> [
    //     18172727478723733672122242648004425580927771110712257632781054272274332874233n, // daoDataEscrowEphemeralPubKeyAx
    //     18696859439217809465524370245449396885627295546811556940609392448191776076084n // daoDataEscrowEphemeralPubKeyAy
    //   ]
    // console.log('ephemeralPubKey=>', ephemeralPubKey);

    // DataEscrowElGamalEncryptionPoint(PointsSize) computations
    // [1] - create k-seed
    const kSeed = poseidon([sharedPubKey[0], sharedPubKey[1]]);
    // 13154798164003983271524044625575471051064665256918638108381540700491567738040n
    // console.log('kSeed=>', kSeed);

    // [2] - encrypted data
    const helperHash = poseidon([kSeed, 0]);
    // 20817835718270251651197535230431667666002689244390372070105221466841400350873n
    // console.log('helperHash=>', helperHash);

    const encryptedMessage = pointMessage[0][0] + helperHash;
    // 25119752029245550546918698028332638709394729887530579652283186635694446943849n
    // console.log('encryptedMessage=>', encryptedMessage);

    const moduloEncryptedMessage = encryptedMessage % SNARK_FIELD;
    // 3231509157406275324672292283075363620846365487114545308584982449118638448232n
    // console.log('moduloEncryptedMessage=>', moduloEncryptedMessage);

    // [3] - cipher message hash
    const encryptedMessageHash = poseidon([moduloEncryptedMessage]);
    // 8548020980957111797668615943249179300643837380790248422888287045915233337316n
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

    // [4] - hmac
    const kMac = poseidon([kSeed, 1]);

    // 0xd836363636363636363636363636363636363636363636363636363636363636
    let ipad =
        97795359191332584535587663717355991292619291276890730051339681934624425391670n;

    // let ipadModular = ipad % SNARK_FIELD;

    // function bigIntXOR(a: bigint, b: bigint) {
    //     let abMul2 = (2n * a * b) % SNARK_FIELD;
    //     let aplusb = a + b;
    //     let aplusBMinusAbMul2 = aplusb - abMul2;
    //     let resultOfXor =
    //         ((aplusBMinusAbMul2 % SNARK_FIELD) + SNARK_FIELD) % SNARK_FIELD;
    //     return resultOfXor;
    // }

    // const kMacInner = bigIntXOR(kMac, ipadModular);
    // 6925611723450430582691980965493394553822066518673126279541304893051063232587n
    // console.log('kMacInner=>', kMacInner);

    const innerHMacSize = 2;
    const innerHMacHash = poseidon([kMac, moduloEncryptedMessage]);
    // 18542453698443514108306900604965174804407245441875486693387851602742667558917n
    // console.log('innerHMacHash=>', innerHMacHash);

    // outerXor computation
    // 0x1c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c;
    // let opad =
    //     12827947140996794198885805201942876066097557124722925231822261757739395734620n;
    // let opadModular = opad % SNARK_FIELD;
    // // console.log("opadModular=>",opadModular);

    // const kMacOuter = bigIntXOR(kMac, opadModular);

    const hmacSize = 2;
    const hmacHash = poseidon([kMac, innerHMacHash]);
    // 8440119056753462523052864914696055620425883804111543984578190069357722526741n
    // console.log('hmacHash=>', hmacHash);

    const input = {
        ephemeralRandom: daoDataEscrowEphemeralRandom,
        pointMessage: pointMessage,
        pubKey: daoDataEscrowPubKey,
    };

    const output = {
        ephemeralPubKey: [ephemeralPubKey[0], ephemeralPubKey[1]], // 18172727478723733672122242648004425580927771110712257632781054272274332874233n, 18696859439217809465524370245449396885627295546811556940609392448191776076084n
        encryptedMessage: [moduloEncryptedMessage], // 3231509157406275324672292283075363620846365487114545308584982449118638448232n
        encryptedMessageHash: encryptedMessageHash, // 8548020980957111797668615943249179300643837380790248422888287045915233337316n
        hmac: hmacHash, // 8081035620019166524915505925588464047085389491348593371364462372175687710253n
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await daoDataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );

            const indexOfephemeralPubKey0 = wtns.indexOf(
                output.ephemeralPubKey[0],
            );
            const indexOfephemeralPubKey1 = wtns.indexOf(
                output.ephemeralPubKey[1],
            );
            const indexOfencryptedMessage = wtns.indexOf(
                output.encryptedMessage[0],
            );
            const indexOfencryptedMessageHash = wtns.indexOf(
                output.encryptedMessageHash,
            );
            const indexOfhmac = wtns.indexOf(output.hmac);

            const wtnsFormattedOutput = [
                0,
                wtns[indexOfephemeralPubKey0],
                wtns[indexOfephemeralPubKey1],
                wtns[indexOfencryptedMessage],
                wtns[indexOfencryptedMessageHash],
                wtns[indexOfhmac],
            ];

            await daoDataEscrowElGamalEncryption.assertOut(
                wtnsFormattedOutput,
                output,
            );

            console.log('Witness calculation successful!');
        });
    });
});
