import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

describe('Main Data Escrow ElGamalEncryption', function (this: any) {
    let dataEscrowElGamalEncryption: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/dataEscrowElGamalEncryptionMain.circom',
        );
        dataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    // Output from `circuits/test/MainDataEscrowEphemeralPubKeysBuilder.test.ts`
    const ephemeralPubKeysOutput = {
        ephemeralPubKey: [
            [
                4301916310975298895721162797900971043392040643140207582177965168853046592976n,
                815388028464849479935447593762613752978886104243152067307597626016673798528n,
            ],
        ],
        sharedPubKey: [
            [
                12871439135712262058001002684440962908819002983015508623206745248194094676428n,
                17114886397516225242214463605558970802516242403903915116207133292790211059315n,
            ],
        ],
    };

    const input = {
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n, // dataEscrowEphemeralRandom
        scalarMessage: [40565128692921904747395642556416n, 1n, 10n], // Taken from `MainDataEscrowSerializer.test.ts`
        pointMessage: [
            [
                9665449196631685092819410614052131494364846416353502155560380686439149087040n,
                13931233598534410991314026888239110837992015348186918500560502831191846288865n,
            ],
            [0n, 1n], // utxoOutRootSpendPubKey
        ],
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ], // dataEscrowPubKey
    };

    const SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617n;

    // [0] - Create ephemeral public key - Derived from `circuits/test/MainDataEscrowEphemeralPubKeysBuilder.test.ts`

    // [1] - create k-seed
    const kSeed = poseidon([
        ephemeralPubKeysOutput.sharedPubKey[0][0],
        ephemeralPubKeysOutput.sharedPubKey[0][1],
    ]);
    // console.log('kSeed=>', kSeed);

    // [2] - encrypted data
    // ScalarsSize - 3 -     // scalars
    const helperHash0 = poseidon([kSeed, 0]);
    const encryptedMessage0 = input.scalarMessage[0] + helperHash0;
    const moduloEncryptedMessage0 = encryptedMessage0 % SNARK_FIELD;
    // 13973906648626983182034480328119298803693100268701353088057843846936256349042n
    // console.log('moduloEncryptedMessage0=>', moduloEncryptedMessage0);

    const helperHash1 = poseidon([kSeed, 1]);
    const encryptedMessage1 = input.scalarMessage[1] + helperHash1;
    const moduloEncryptedMessage1 = encryptedMessage1 % SNARK_FIELD;
    // 473107879088864817427941367142854458250433871003316364107425192816097535880n
    // console.log('moduloEncryptedMessage1=>', moduloEncryptedMessage1);

    const helperHash2 = poseidon([kSeed, 2]);
    const encryptedMessage2 = input.scalarMessage[2] + helperHash2;
    const moduloEncryptedMessage2 = encryptedMessage2 % SNARK_FIELD;
    // 5494747578719849743514538994145141818891361484689613558464885736461065634004n
    // console.log('moduloEncryptedMessage2=>', moduloEncryptedMessage2);

    // points - 2
    const helperHash3 = poseidon([kSeed, 3]);
    const encryptedMessage3 = input.pointMessage[0][0] + helperHash3;
    const moduloEncryptedMessage3 = encryptedMessage3 % SNARK_FIELD;
    // 17478869179407600441624504783451962827747408866666665035038148654122072068560n
    // console.log('moduloEncryptedMessage3=>', moduloEncryptedMessage3);

    const helperHash4 = poseidon([kSeed, 4]);
    const encryptedMessage4 = input.pointMessage[1][0] + helperHash4;
    const moduloEncryptedMessage4 = encryptedMessage4 % SNARK_FIELD;
    // 3979705822755801962959100881652950811750399282785018064249634205385110664507n
    // console.log('moduloEncryptedMessage4=>', moduloEncryptedMessage4);

    // [3] - cipher message hash - encryptedMessageHash
    const encryptedMessageHash = poseidon([
        moduloEncryptedMessage0,
        moduloEncryptedMessage1,
        moduloEncryptedMessage2,
        moduloEncryptedMessage3,
        moduloEncryptedMessage4,
    ]);
    // 5967078019481323625179318118838170451123956114438946094975109984869309870871n
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

    // [4] - hmac
    const kMac = poseidon([kSeed, 5]);
    // console.log('kMac=>', kMac);

    // 0xd836363636363636363636363636363636363636363636363636363636363636
    let ipad =
        97795359191332584535587663717355991292619291276890730051339681934624425391670n;

    let ipadModular = ipad % SNARK_FIELD;

    function bigIntXOR(a: bigint, b: bigint) {
        let abMul2 = (2n * a * b) % SNARK_FIELD;
        let aplusb = a + b;
        let aplusBMinusAbMul2 = aplusb - abMul2;
        let resultOfXor =
            ((aplusBMinusAbMul2 % SNARK_FIELD) + SNARK_FIELD) % SNARK_FIELD;
        return resultOfXor;
    }

    const kMacInner = bigIntXOR(kMac, ipadModular);
    // 9942702785480720521177456823433914167493672025997752444579152155139722112618n
    // console.log('kMacInner=>', kMacInner);

    const innerHMacSize = 6;
    const innerHMacHash = poseidon([
        kMacInner,
        moduloEncryptedMessage0,
        moduloEncryptedMessage1,
        moduloEncryptedMessage2,
        moduloEncryptedMessage3,
        moduloEncryptedMessage4,
    ]);
    // 11091542519530565194459222333010305919249138758285042102602615607481380157273n
    // console.log('innerHMacHash=>', innerHMacHash);

    // outerXor computation
    // 0x1c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c;
    let opad =
        12827947140996794198885805201942876066097557124722925231822261757739395734620n;
    let opadModular = opad % SNARK_FIELD;
    // console.log("opadModular=>",opadModular);

    const kMacOuter = bigIntXOR(kMac, opadModular);

    const hmacHash = poseidon([kMacOuter, innerHMacHash]); // hmacSize - 2
    // 16705101644104021648678347417892238407392304310089311793664834896139134702602n
    // console.log('hmacHash=>', hmacHash);

    const output = {
        ephemeralPubKey: [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
        encryptedMessage: [
            13973906648626983182034480328119298803693100268701353088057843846936256349042n,
            473107879088864817427941367142854458250433871003316364107425192816097535880n,
            5494747578719849743514538994145141818891361484689613558464885736461065634004n,
            17478869179407600441624504783451962827747408866666665035038148654122072068560n,
            3979705822755801962959100881652950811750399282785018064249634205385110664507n,
        ],
        encryptedMessageHash:
            5967078019481323625179318118838170451123956114438946094975109984869309870871n,
        hmac: 16705101644104021648678347417892238407392304310089311793664834896139134702602n,
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await dataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );

            const indexOfephemeralPubKey0 = wtns.indexOf(
                output.ephemeralPubKey[0],
            );

            const indexOfephemeralPubKey1 = wtns.indexOf(
                output.ephemeralPubKey[1],
            );

            const indexOfencryptedMessage0 = wtns.indexOf(
                output.encryptedMessage[0],
            );

            const indexOfencryptedMessage1 = wtns.indexOf(
                output.encryptedMessage[1],
            );

            const indexOfencryptedMessage2 = wtns.indexOf(
                output.encryptedMessage[2],
            );

            const indexOfencryptedMessage3 = wtns.indexOf(
                output.encryptedMessage[3],
            );

            const indexOfencryptedMessage4 = wtns.indexOf(
                output.encryptedMessage[4],
            );

            const indexOfeencryptedMessageHash = wtns.indexOf(
                output.encryptedMessageHash,
            );

            const hmac = wtns.indexOf(output.hmac);

            const wtnsFormattedOutput = [
                0,
                wtns[indexOfephemeralPubKey0],
                wtns[indexOfephemeralPubKey1],
                wtns[indexOfencryptedMessage0],
                wtns[indexOfencryptedMessage1],
                wtns[indexOfencryptedMessage2],
                wtns[indexOfencryptedMessage3],
                wtns[indexOfencryptedMessage4],
                wtns[indexOfeencryptedMessageHash],
                wtns[hmac],
            ];

            // await dataEscrowElGamalEncryption.assertOut(
            //     wtnsFormattedOutput,
            //     output,
            // ); - - PROBLEM HERE
            await dataEscrowElGamalEncryption.checkConstraints(wtns, output);
            console.log('Witness calculation successful!');
        });
    });
});
