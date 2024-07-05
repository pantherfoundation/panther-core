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
import poseidon from 'circomlibjs/src/poseidon';
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

    // Add comment during Stage8 - @sushma
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

    const sharedPubKey = [
        [
            12871439135712262058001002684440962908819002983015508623206745248194094676428n,
            17114886397516225242214463605558970802516242403903915116207133292790211059315n,
        ],
        [
            21758777979755803182538129900028133174295707744114450068664463558509866946614n,
            3383300988664032323093307926408339105249322517803146002338186492453973025540n,
        ],
        [
            14293550905890812241513963746533083266680267788344787504362222884247937583948n,
            7099857930707147205874694078600665048800447862993029468367125942432785529865n,
        ],
        [
            21048703529413494861678330491982795372081697410581009038694545528467383891023n,
            12937632546172759800376361787425669329273322717353043445508290209715276281180n,
        ],
        [
            7297019676557908962042586301228473229974050274733665238000356125776043229580n,
            18563600283174270791878032698229089257216528163421448747381920368937416047481n,
        ],
        [
            12307689630899618246480794955690692804352458820002011150464688179243001334182n,
            19309498603063743211985059488051285201203283655164493866609326895417469311159n,
        ],
        [
            13140356701232512173966320933649774106760292720114501831619703835914424987113n,
            9291699154248073182843366647947932971830086229525261214579447602535534688695n,
        ],
        [
            2182025380965896497460628247978912543037090228604943640959096322498395514459n,
            19509051699743263324659030264421893806792853663902545359902021332792072507588n,
        ],
        [
            9393771215338765851039916609890999297841092873615191318045611850804053530293n,
            10518333461259151968323670901221007528436216543066704767006882719625619977509n,
        ],
        [
            19422562726954330262366342847200985885831954851878368123062828465738895330962n,
            12463481783339713254340340992496598380770245140406136963354707869635762047176n,
        ],
    ];

    // encryptedMessage[ScalarsSize+PointsSize][2] computation
    const scalarMessagePoints0 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[0]
    );
    const encryptedMessage0 = babyjub.addPoint(
        scalarMessagePoints0,
        sharedPubKey[0],
    );
    // console.log('encryptedMessage0=>', encryptedMessage0);

    const scalarMessagePoints1 = babyjub.mulPointEscalar(
        babyjub.Base8,
        2162689, //scalarMessage[1]
    );
    const encryptedMessage1 = babyjub.addPoint(
        scalarMessagePoints1,
        sharedPubKey[1],
    );
    // console.log('encryptedMessage1=>', encryptedMessage1);

    const scalarMessagePoints2 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[1]
    );
    const encryptedMessage2 = babyjub.addPoint(
        scalarMessagePoints2,
        sharedPubKey[2],
    );
    // console.log('encryptedMessage2=>', encryptedMessage2);

    const scalarMessagePoints3 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[3]
    );
    const encryptedMessage3 = babyjub.addPoint(
        scalarMessagePoints3,
        sharedPubKey[3],
    );
    // console.log('encryptedMessage3=>', encryptedMessage3);

    const scalarMessagePoints4 = babyjub.mulPointEscalar(
        babyjub.Base8,
        10, //scalarMessage[4]
    );
    const encryptedMessage4 = babyjub.addPoint(
        scalarMessagePoints4,
        sharedPubKey[4],
    );
    // console.log('encryptedMessage4=>', encryptedMessage4);

    const scalarMessagePoints5 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[5]
    );
    const encryptedMessage5 = babyjub.addPoint(
        scalarMessagePoints5,
        sharedPubKey[5],
    );
    // console.log('encryptedMessage5=>', encryptedMessage5);

    const scalarMessagePoints6 = babyjub.mulPointEscalar(
        babyjub.Base8,
        1, //scalarMessage[6]
    );
    const encryptedMessage6 = babyjub.addPoint(
        scalarMessagePoints6,
        sharedPubKey[6],
    );
    // console.log('encryptedMessage6=>', encryptedMessage6);

    const scalarMessagePoints7 = babyjub.mulPointEscalar(
        babyjub.Base8,
        0, //scalarMessage[7]
    );
    const encryptedMessage7 = babyjub.addPoint(
        scalarMessagePoints7,
        sharedPubKey[7],
    );
    // console.log('encryptedMessage7=>', encryptedMessage7);

    const encryptedMessage8 = babyjub.addPoint(
        [
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ],
        sharedPubKey[8],
    );
    // console.log('encryptedMessage8=>', encryptedMessage8);

    const encryptedMessage9 = babyjub.addPoint([0n, 0n], sharedPubKey[9]);
    // console.log('encryptedMessage9=>', encryptedMessage9);

    // encryptedMessageHash computation - MultiPoseidon
    const encryptedMessageHash0 = poseidon([
        encryptedMessage0[0],
        encryptedMessage0[1],
        encryptedMessage1[0],
        encryptedMessage1[1],
        encryptedMessage2[0],
        encryptedMessage2[1],
        encryptedMessage3[0],
        encryptedMessage3[1],
        encryptedMessage4[0],
        encryptedMessage4[1],
    ]);
    // console.log('encryptedMessageHash0=>', encryptedMessageHash0);

    const encryptedMessageHash1 = poseidon([
        encryptedMessage5[0],
        encryptedMessage5[1],
        encryptedMessage6[0],
        encryptedMessage6[1],
        encryptedMessage7[0],
        encryptedMessage7[1],
        encryptedMessage8[0],
        encryptedMessage8[1],
        encryptedMessage9[0],
        encryptedMessage9[1],
    ]);
    // console.log('encryptedMessageHash1=>', encryptedMessageHash1);

    const encryptedMessageHash = poseidon([
        encryptedMessageHash0,
        encryptedMessageHash1,
    ]);
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

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
        encryptedMessageHash: encryptedMessageHash,
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
