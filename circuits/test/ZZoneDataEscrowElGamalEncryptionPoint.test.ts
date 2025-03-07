import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';
import poseidon from 'circomlibjs/src/poseidon';

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

    const SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617n;

    // EphemeralPubKeysBuilder
    // Input: pubKey[2], ephemeralRandom
    // Output: ephemeralPubKey[2], sharedPubKey[2]
    const zZoneDataEscrowEphemeralRandom =
        790122152066676684676093302872898287841903882354339429497975929636832086290n; // zZoneDataEscrowEphemeralRandom

    const zZoneEdDsaPubKey = [
        13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        11069452135192839850369824221357904553346382352990372044246668947825855305207n,
    ]; // zZoneEdDsaPubKey

    // Input to DataEscrowElGamalEncryptionPoint
    const pointMessage = [
        [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n, // dataEscrowEphemeralPubKeyAx
            815388028464849479935447593762613752978886104243152067307597626016673798528n, // dataEscrowEphemeralPubKeyAy
        ],
    ];

    const sharedPubKey = babyjub.mulPointEscalar(
        zZoneEdDsaPubKey,
        zZoneDataEscrowEphemeralRandom.toString(),
    );

    const ephemeralPubKey = babyjub.mulPointEscalar(
        babyjub.Base8,
        zZoneDataEscrowEphemeralRandom,
    );
    // ephemeralPubKey=> [
    //     8203289148254703516772267706874329469330087297928457772489392227653451244213n, - zZoneDataEscrowEphemeralPubKeyAx
    //     19998992060707539017877331634603765261877243592349009808298088607668947098216n - zZoneDataEscrowEphemeralPubKeyAy
    //   ]
    // console.log('ephemeralPubKey=>', ephemeralPubKey);

    // DataEscrowElGamalEncryptionPoint(PointsSize) computations
    // [1] - create k-seed
    const kSeed = poseidon([sharedPubKey[0], sharedPubKey[1]]);

    // [2] - encrypted data
    const helperHash = poseidon([kSeed, 0]);
    const encryptedMessage = pointMessage[0][0] + helperHash;
    // 21022076763366182175477357918933442131485472229146225036655452082762082124322n
    // console.log('encryptedMessage=>', encryptedMessage);

    const moduloEncryptedMessage = encryptedMessage % SNARK_FIELD;
    // 21022076763366182175477357918933442131485472229146225036655452082762082124322n
    // console.log('moduloEncryptedMessage=>', moduloEncryptedMessage);

    // [3] - cipher message hash
    const encryptedMessageHash = poseidon([encryptedMessage]);
    // encryptedMessageHash=> 12444185887568679379186315345524877022401565154030591259044587421593238202125n
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

    // [4] - hmac
    const kMac = poseidon([kSeed, 1]);

    // 0xd836363636363636363636363636363636363636363636363636363636363636
    // let ipad =
    //     97795359191332584535587663717355991292619291276890730051339681934624425391670n;

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
    // // 21797284874701574539809215683527628528498093308347464104746414623680031777585n
    // // console.log('kMacInner=>', kMacInner);

    let innerHMacSize = 2; // 1+1
    const innerHMacHash = poseidon([kMac, moduloEncryptedMessage]);
    // 19457888664929498929543237240690469023928612450344569641056481447681365892438n
    // console.log('innerHMacHash=>', innerHMacHash);

    // // outerXor computation
    // // 0x1c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c;
    // let opad =
    //     12827947140996794198885805201942876066097557124722925231822261757739395734620n;
    // let opadModular = opad % SNARK_FIELD;
    // // console.log("opadModular=>",opadModular);

    // const kMacOuter = bigIntXOR(kMac, opadModular);

    const hmacHash = poseidon([kMac, innerHMacHash]); // hmacSize = 2
    // 14496019412495389807807919111786846616937183677820347136868875172131919005507
    // console.log('hmacHash=>', hmacHash);

    const input = {
        ephemeralRandom: zZoneDataEscrowEphemeralRandom,
        pointMessage: pointMessage,
        pubKey: zZoneEdDsaPubKey,
    };

    const output = {
        ephemeralPubKey: [ephemeralPubKey[0], ephemeralPubKey[1]], // 8203289148254703516772267706874329469330087297928457772489392227653451244213n, 19998992060707539017877331634603765261877243592349009808298088607668947098216n
        encryptedMessage: [encryptedMessage], // 21022076763366182175477357918933442131485472229146225036655452082762082124322n
        encryptedMessageHash: encryptedMessageHash, // 12444185887568679379186315345524877022401565154030591259044587421593238202125n
        hmac: hmacHash, // 14496019412495389807807919111786846616937183677820347136868875172131919005507
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

            await zZoneDataEscrowElGamalEncryption.assertOut(
                wtnsFormattedOutput,
                output,
            );

            console.log('Witness calculation successful!');
        });
    });
});
