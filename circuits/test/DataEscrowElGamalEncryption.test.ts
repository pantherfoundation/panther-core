import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub} from 'circomlibjs';
import {generateRandomKeypair} from '@panther-core/crypto/lib/base/keypairs';
import {getRandomInt} from './helpers/utility';
import {
    generateRandom256Bits,
    generateRandomInBabyJubSubField,
} from '@panther-core/crypto/lib/base/field-operations';
import {Scalar} from 'ffjavascript';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';
const {shiftLeft} = Scalar;
const {bor} = Scalar;

// Cleanup test during Stage8 - @sushma
describe('DataEscrowElGamalEncryption circuit', function (this: any) {
    let dataEscrowElGamalEncryption: any;

    this.timeout(10_000_000);

    before(async function () {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './test/circuits/dataEscrowElGamalEncryption.circom',
        );
        dataEscrowElGamalEncryption = await wasm_tester(input, opts);
    });

    // Recheck comment during Stage8 - @sushma
    /*******************************************************************************************************************
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// component main = DataEscrowElGamalEncryption(8-scalars,2-Points); ///////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        1) 8 - scalar size, 2 point size (Please refer to DataEscrowSerializer code)
            ----- 2 for 2 x Point(x,y) ------
            1 - utxoOut-1-RootPubKey[x,y]
            2 - utxoOut-2-RootPubKey[x,y]
            -----------------------------------
            ----- 8 for 8 x 64 bit values -----
            signal input zAsset;                          // 64 bit
            signal input zAccountId;                      // 24 bit
            signal input zAccountZoneId;                  // 16 bit

            signal input utxoInAmount[nUtxoIn=2];         // 64 bit
            signal input utxoOutAmount[nUtxoOut=2];       // 64 bit

            signal input utxoInOriginZoneId[nUtxoIn=2];   // 16 bit
            signal input utxoOutTargetZoneId[nUtxoOut=2]; // 16 bit

            1 - zAsset (32 bit)
            2 - zAccountID (24 bit) << 16 | zAccountZoneId (16 bit)
            3 - utxoInAmount-1 (64 bit)
            4 - utxoInAmount-2 (64 bit)
            5 - utxoOutAmount-1 (64 bit)
            6 - utxoOutAmount-2 (64 bit)
            7 - utxoInOriginZoneId-1 (16 bit) << 16 | utxoOutTargetZoneId-1 (16 bit)
            8 - utxoInOriginZoneId-2 (16 bit) << 16 | utxoOutTargetZoneId-2 (16 bit)
            -----------------------------------
        2) ephemeralRandom, ephemeralPubKey[x,y], pubKey[x,y]
           2.1) ephemeralPubKey[x,y] == ephemeralRandom * G
           2.2) pubKey[x,y] - pubKey that its inclusion is proven
        3) encryptedMessage[8(scalars)+2(points)][x,y] - encrypted points
            3.1) ephemeralRandomPubKey[x,y] = pubKey[x,y] * ephemeralRandom
            3.2) Encrypt scalars:
                3.2.1) scalar mapping: M_scalar_points = m_scalar * G for each scalar out of 8
                    --> M_scalar_points[8][x,y]
                3.2.2) elgamal: encryptedscalars[8][x,y] = M_scalar_points[8][x,y] + ephemeralRandomPubKey[x,y]
            3.3) Encrypt Points:
                3.3.1) elgamal: encyptedPoints[2][x,y] = M_points[2][x,y] + ephemeralRandomPubKey[x,y]
        4) Encrypted Output
            4.1) encyptedMessage[0-to-7][x,y] = encryptedscalars[8][x,y]
            4.2) encyptedMessage[8-to-9][x,y] = encryptedPoints[8][x,y]
     ******************************************************************************************************************/
    const input = {
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n,
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
        scalarMessage: [0, 2162689, 0, 0, 10, 0, 1, 0],
        // Values from `DepositOnlyNonZeroInputWitnessGeneration.test.ts`
        pointMessage: [
            [
                9665449196631685092819410614052131494364846416353502155560380686439149087040n,
                13931233598534410991314026888239110837992015348186918500560502831191846288865n,
            ],
            [0, 0],
        ],
    };

    const ephemeralRandomPubKey = [
        [
            12871439135712262058001002684440962908819002983015508623206745248194094676428n,
            17114886397516225242214463605558970802516242403903915116207133292790211059315n,
        ],
        [
            14715282785645531699299359324879767610524506554829132351240969655805786153311n,
            16298106068662121661386726371313267600592270658346075539160130615717895345005n,
        ],
        [
            5076630596576156879056817266673921939822187766485023884697508842383654864701n,
            18537582780122882427504865698450965640562756141929860651411897814057616549835n,
        ],
        [
            20523581000037863852326059229764216089225350671364692666825542079348693914995n,
            5781176486616316053750229455982357786563481303510351065692534349340256489076n,
        ],
        [
            10378265944428119107711332533449804910732315585881693008237106152055045103347n,
            21029920917937143156010888140502192636742393695727430950191808014440353201325n,
        ],
        [
            15957016481248729440226604571571896292382014480898746772647102174542471117023n,
            20908710057951135449348158838741423296989266876751621333915428201200659885936n,
        ],
        [
            16414818090013652009115609217866261951817223138597235575004168391221688060610n,
            20059661808734730259039633106635683938416748943430928650775690601990727667285n,
        ],
        [
            18224078447721468913448619229779986050619236635302325031880878071400013184997n,
            12229800567381579225866236980070374176299043182345544547937919767427587709148n,
        ],
        [
            3462515991558629614614530863822019927194326138941210737711776530604922106525n,
            18171187893064681019827124267070423101397852328497300082251783410349806754356n,
        ],
        [
            8440660080386163641088243662813324731029409616187751210324775028349462183564n,
            8433802572435888741254663080553586984999830087708251743134449562704293198957n,
        ],
    ];

    // encryptedMessage[ScalarsSize+PointsSize][2] computation
    const ephemeralPubKey0 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[0]
    );
    const encryptedMessage0 = babyjub.addPoint(
        ephemeralPubKey0,
        ephemeralRandomPubKey[0],
    );
    // console.log('encryptedMessage0=>', encryptedMessage0);

    const ephemeralPubKey1 = babyjub.mulPointEscalar(
        babyjub.Base8,
        2162689, //scalarMessage[1]
    );
    const encryptedMessage1 = babyjub.addPoint(
        ephemeralPubKey1,
        ephemeralRandomPubKey[1],
    );
    // console.log('encryptedMessage1=>', encryptedMessage1);

    const ephemeralPubKey2 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[1]
    );
    const encryptedMessage2 = babyjub.addPoint(
        ephemeralPubKey2,
        ephemeralRandomPubKey[2],
    );
    // console.log('encryptedMessage2=>', encryptedMessage2);

    const ephemeralPubKey3 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[3]
    );
    const encryptedMessage3 = babyjub.addPoint(
        ephemeralPubKey3,
        ephemeralRandomPubKey[3],
    );
    // console.log('encryptedMessage3=>', encryptedMessage3);

    const ephemeralPubKey4 = babyjub.mulPointEscalar(
        babyjub.Base8,
        10, //scalarMessage[4]
    );
    const encryptedMessage4 = babyjub.addPoint(
        ephemeralPubKey4,
        ephemeralRandomPubKey[4],
    );
    // console.log('encryptedMessage4=>', encryptedMessage4);

    const ephemeralPubKey5 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[5]
    );
    const encryptedMessage5 = babyjub.addPoint(
        ephemeralPubKey5,
        ephemeralRandomPubKey[5],
    );
    // console.log('encryptedMessage5=>', encryptedMessage5);

    const ephemeralPubKey6 = babyjub.mulPointEscalar(
        babyjub.Base8,
        1, //scalarMessage[6]
    );
    const encryptedMessage6 = babyjub.addPoint(
        ephemeralPubKey6,
        ephemeralRandomPubKey[6],
    );
    // console.log('encryptedMessage6=>', encryptedMessage6);

    const ephemeralPubKey7 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[7]
    );
    const encryptedMessage7 = babyjub.addPoint(
        ephemeralPubKey7,
        ephemeralRandomPubKey[7],
    );
    // console.log('encryptedMessage7=>', encryptedMessage7);

    const encryptedMessage8 = babyjub.addPoint(
        [
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ],
        ephemeralRandomPubKey[8],
    );
    // console.log('encryptedMessage8=>', encryptedMessage8);

    const encryptedMessage9 = babyjub.addPoint(
        [0n, 0n],
        ephemeralRandomPubKey[9],
    );
    // console.log('encryptedMessage9=>', encryptedMessage9);

    const output = {
        ephemeralPubKey: [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
        encryptedMessage: [
            [encryptedMessage0[0], encryptedMessage0[1]],
            [encryptedMessage1[0], encryptedMessage1[1]],
            [encryptedMessage2[0], encryptedMessage2[1]],
            [encryptedMessage3[0], encryptedMessage3[1]],
            [encryptedMessage4[0], encryptedMessage4[1]],
            [encryptedMessage5[0], encryptedMessage5[1]],
            [encryptedMessage6[0], encryptedMessage6[1]],
            [encryptedMessage7[0], encryptedMessage7[1]],
            [encryptedMessage8[0], encryptedMessage8[1]],
            [encryptedMessage9[0], encryptedMessage9[1]],
        ],
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await dataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );
            await dataEscrowElGamalEncryption.assertOut(wtns, output);
            console.log('Witness calculation successful!');
        });
    });
});
