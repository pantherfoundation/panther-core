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

    // Output from `circuits/test/EphemeralPubKeysBuilder.test.ts`
    const ephemeralPubKeysOutput = {
        ephemeralPubKey: [
            [
                4301916310975298895721162797900971043392040643140207582177965168853046592976n,
                815388028464849479935447593762613752978886104243152067307597626016673798528n,
            ],
            [
                14045942521266055571916590111449484418253039788630914712810367405156451594287n,
                9678685104652269963265200538573612091847371556964665669451023565147453237383n,
            ],
            [
                18591602555818245059410790393174638367301612360404703730359666913909280640866n,
                8691211032423283247187435646553508392761491888895479191173669777559474501012n,
            ],
            [
                10310657327696077950410852339660841183282648508492921428435816309266447528623n,
                4955313689604114651209739799972145686039343843388925957618940764736620625126n,
            ],
            [
                2023013743583669024582501570531200574238078005422996367972090108618071615177n,
                12992455675847417071453654006365260236660494639869702658578914449760570773413n,
            ],
            [
                7764748396296801466418360511393171015314152671685214328549868806181132558650n,
                8340101192968391294960711777133513639801288069228419377447593852767341071026n,
            ],
            [
                15823240360096733079161599597386854649693051253231139792195227220009503914188n,
                9894071729925266345963002954719525974126832669397508145525541589032482243994n,
            ],
            [
                16385640502558012539872120678445830575784217992192168487564958330433274968779n,
                12950685446469144231168738409437007619463731911270180178521564823777086401110n,
            ],
            [
                12885722321397670381498295547157414406696883574058278581530745927647401037922n,
                13028134080686099853800247331357224963774416245072134606341171603418894445878n,
            ],
            [
                7199903909075988357358243084402367162009278159850550718945324356639738668426n,
                7577412086959893072342057579116887385280813589739427103433580293145793641479n,
            ],
            [
                11861630361391895079238566928173864464016475399753492116009099739090318996468n,
                13119895310368360937633802331629602908321224595237611469001534844907122241884n,
            ],
        ],
        sharedPubKey: [
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
            [
                10109339424773877492804669208682365416568345295837959627067555123981613599187n,
                814517807069776295169446144150391725539459863450894144762894033002333230827n,
            ],
        ],
        hidingPoint: [
            21758777979755803182538129900028133174295707744114450068664463558509866946614n,
            3383300988664032323093307926408339105249322517803146002338186492453973025540n,
        ],
    };

    // Add comment during Stage8 - @sushma
    const input = {
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n,
        scalarMessage: [0, 2162689, 2, 0, 0, 10, 0, 1, 0],
        pointMessage: [
            [
                9665449196631685092819410614052131494364846416353502155560380686439149087040n,
                13931233598534410991314026888239110837992015348186918500560502831191846288865n,
            ],
            [0n, 1n],
        ],
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
    };

    // computations
    // First for loop will never get executed

    // [2] - ephemeralRandom * pubKey + M, where M = m * G
    const offset = 0; // offset = offset + PaddingPointsSize;
    // scalarMessage[ScalarsSize] - 9 items - [0, 2162689, 2, 0, 0, 10, 0, 1, 0]

    // encryptedMessage[0][0] & encryptedMessage[0][1]
    const drv_mG0 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[0],
    );
    // console.log('drv_mG0=>', drv_mG0);

    const drv_mGrY0 = babyjub.addPoint(
        drv_mG0,
        ephemeralPubKeysOutput.sharedPubKey[0],
    );
    // console.log('drv_mGrY0=>', drv_mGrY0);

    const drv_mGrY_final0 = babyjub.addPoint(
        drv_mGrY0,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final0=>', drv_mGrY_final0);
    const encryptedMessage0 = drv_mGrY_final0; // 0 - 1st element

    // encryptedMessage[1][0] & encryptedMessage[1][1]
    const drv_mG1 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[1],
    );
    // console.log('drv_mG1=>', drv_mG1);

    const drv_mGrY1 = babyjub.addPoint(
        drv_mG1,
        ephemeralPubKeysOutput.sharedPubKey[1],
    );
    // console.log('drv_mGrY1=>', drv_mGrY1);

    const drv_mGrY_final1 = babyjub.addPoint(
        drv_mGrY1,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final1=>', drv_mGrY_final1);
    const encryptedMessage1 = drv_mGrY_final1; // 1 - 2nd element

    // encryptedMessage[2][0] & encryptedMessage[2][1]
    const drv_mG2 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[2],
    );
    // console.log('drv_mG2=>', drv_mG2);

    const drv_mGrY2 = babyjub.addPoint(
        drv_mG2,
        ephemeralPubKeysOutput.sharedPubKey[2],
    );
    // console.log('drv_mGrY2=>', drv_mGrY2);

    const drv_mGrY_final2 = babyjub.addPoint(
        drv_mGrY2,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final2=>', drv_mGrY_final2);
    const encryptedMessage2 = drv_mGrY_final2; // 2 - 3rd element

    // encryptedMessage[3][0] & encryptedMessage[3][1]
    const drv_mG3 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[3],
    );
    // console.log('drv_mG3=>', drv_mG3);

    const drv_mGrY3 = babyjub.addPoint(
        drv_mG3,
        ephemeralPubKeysOutput.sharedPubKey[3],
    );
    // console.log('drv_mGrY3=>', drv_mGrY3);

    const drv_mGrY_final3 = babyjub.addPoint(
        drv_mGrY3,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final3=>', drv_mGrY_final3);
    const encryptedMessage3 = drv_mGrY_final3; // 3 - 4th element

    // encryptedMessage[4][0] & encryptedMessage[4][1]
    const drv_mG4 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[4],
    );
    // console.log('drv_mG4=>', drv_mG4);

    const drv_mGrY4 = babyjub.addPoint(
        drv_mG4,
        ephemeralPubKeysOutput.sharedPubKey[4],
    );
    // console.log('drv_mGrY4=>', drv_mGrY4);

    const drv_mGrY_final4 = babyjub.addPoint(
        drv_mGrY4,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final4=>', drv_mGrY_final4);
    const encryptedMessage4 = drv_mGrY_final4; // 4 - 5th element

    // encryptedMessage[5][0] & encryptedMessage[5][1]
    const drv_mG5 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[5],
    );
    // console.log('drv_mG5=>', drv_mG5);

    const drv_mGrY5 = babyjub.addPoint(
        drv_mG5,
        ephemeralPubKeysOutput.sharedPubKey[5],
    );
    // console.log('drv_mGrY5=>', drv_mGrY5);

    const drv_mGrY_final5 = babyjub.addPoint(
        drv_mGrY5,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final5=>', drv_mGrY_final5);
    const encryptedMessage5 = drv_mGrY_final5; // 5 - 6th element

    // encryptedMessage[6][0] & encryptedMessage[6][1]
    const drv_mG6 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[6],
    );
    // console.log('drv_mG6=>', drv_mG6);

    const drv_mGrY6 = babyjub.addPoint(
        drv_mG6,
        ephemeralPubKeysOutput.sharedPubKey[6],
    );
    // console.log('drv_mGrY6=>', drv_mGrY6);

    const drv_mGrY_final6 = babyjub.addPoint(
        drv_mGrY6,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final6=>', drv_mGrY_final6);
    const encryptedMessage6 = drv_mGrY_final6; // 6 - 7th element

    // encryptedMessage[7][0] & encryptedMessage[7][1]
    const drv_mG7 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[7],
    );
    // console.log('drv_mG7=>', drv_mG7);

    const drv_mGrY7 = babyjub.addPoint(
        drv_mG7,
        ephemeralPubKeysOutput.sharedPubKey[7],
    );
    // console.log('drv_mGrY7=>', drv_mGrY7);

    const drv_mGrY_final7 = babyjub.addPoint(
        drv_mGrY7,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final7=>', drv_mGrY_final7);
    const encryptedMessage7 = drv_mGrY_final7; // 7 - 8th element

    // encryptedMessage[8][0] & encryptedMessage[8][1]
    const drv_mG8 = babyjub.mulPointEscalar(
        babyjub.Base8,
        input.scalarMessage[8],
    );
    // console.log('drv_mG8=>', drv_mG8);

    const drv_mGrY8 = babyjub.addPoint(
        drv_mG8,
        ephemeralPubKeysOutput.sharedPubKey[8],
    );
    // console.log('drv_mGrY8=>', drv_mGrY8);

    const drv_mGrY_final8 = babyjub.addPoint(
        drv_mGrY8,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final8=>', drv_mGrY_final8);
    const encryptedMessage8 = drv_mGrY_final8; // 8 - 9th element

    // encryptedMessage[9][0] & encryptedMessage[9][1]
    // point details
    const drv_mGrY9 = babyjub.addPoint(
        input.pointMessage[0],
        ephemeralPubKeysOutput.sharedPubKey[9],
    );
    // console.log('drv_mGrY9=>', drv_mGrY9);

    const drv_mGrY_final9 = babyjub.addPoint(
        drv_mGrY9,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final9=>', drv_mGrY_final9);
    const encryptedMessage9 = drv_mGrY_final9; // 9 - 10th element

    // encryptedMessage[10][0] & encryptedMessage[10][1]
    const drv_mGrY10 = babyjub.addPoint(
        input.pointMessage[1],
        ephemeralPubKeysOutput.sharedPubKey[10],
    );
    // console.log('drv_mGrY10=>', drv_mGrY10);

    const drv_mGrY_final10 = babyjub.addPoint(
        drv_mGrY10,
        ephemeralPubKeysOutput.hidingPoint,
    );
    // console.log('drv_mGrY_final10=>', drv_mGrY_final10);
    const encryptedMessage10 = drv_mGrY_final10; // 10 - 11th element

    // encryptedMessageHash computation
    const n1 = poseidon([
        4466207087396908530538027508480327289709135098369366605035498754018548098580n,
        2206378257592766967667444778490995501001254338204335097462312906524713313893n,
        273074978062481213664850189152101320277724757435031910618470992057413125749n,
        3333160868102876910995378449615424584834191665884607534873759487264725242723n,
        3221881113978258341351905607022453683468074110539600327144632860643312043607n,
        8234487486561785093301815874679075174968982285316177860525130662867034203225n,
        6385720989959316442888186252300422065905111644716791543232066803264608411643n,
        1536289756199432030510151465306154455153333141586487083330688676636024498143n,
        19481776160681562933683231160237503115470387605976263433224989106147562447425n,
        4418840501277900235948807656537418162878623322725443058555029157941160468861n,
        16063003973509268587369077687850423627809939628320499612404676550495072514110n,
    ]);

    const n2 = poseidon([
        8283809066088154732664292412535519471257859888299500970909114628636257843398n,
        21566146839273838550739020905682209904771181834353214903291684782216436330590n,
        14209394576476591299961251260489532744973900798931789373358600111270609092544n,
        8519267136277463825745824815461272821853226998548930937779596463704159990950n,
        15133860638344272965838177823352282544348692353440495231643111403641673471151n,
        221587156352960568833477715860467505765088050847549918946361730170783196336n,
        5241658287428607961362615607434330957330063744475866285584509561524463161024n,
        2968714453246211896005611797264008792287473229252515375565227354980763726284n,
        4706539374333453611370871310272906412651633111294392668226252198982372846324n,
        4931415214415797016210444707986521039263270801914587984123419292259499277160n,
        6988657263078170402537509816874598318402282044107987160758020550057166654636n,
    ]);

    const encryptedMessageHash = poseidon([n1, n2]);
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

    const output = {
        ephemeralPubKey: [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
        encryptedMessage: [
            [
                4466207087396908530538027508480327289709135098369366605035498754018548098580n,
                2206378257592766967667444778490995501001254338204335097462312906524713313893n,
            ],
            [
                273074978062481213664850189152101320277724757435031910618470992057413125749n,
                3333160868102876910995378449615424584834191665884607534873759487264725242723n,
            ],
            [
                3221881113978258341351905607022453683468074110539600327144632860643312043607n,
                8234487486561785093301815874679075174968982285316177860525130662867034203225n,
            ],
            [
                6385720989959316442888186252300422065905111644716791543232066803264608411643n,
                1536289756199432030510151465306154455153333141586487083330688676636024498143n,
            ],
            [
                19481776160681562933683231160237503115470387605976263433224989106147562447425n,
                4418840501277900235948807656537418162878623322725443058555029157941160468861n,
            ],
            [
                16063003973509268587369077687850423627809939628320499612404676550495072514110n,
                8283809066088154732664292412535519471257859888299500970909114628636257843398n,
            ],
            [
                21566146839273838550739020905682209904771181834353214903291684782216436330590n,
                14209394576476591299961251260489532744973900798931789373358600111270609092544n,
            ],
            [
                8519267136277463825745824815461272821853226998548930937779596463704159990950n,
                15133860638344272965838177823352282544348692353440495231643111403641673471151n,
            ],
            [
                221587156352960568833477715860467505765088050847549918946361730170783196336n,
                5241658287428607961362615607434330957330063744475866285584509561524463161024n,
            ],
            [
                2968714453246211896005611797264008792287473229252515375565227354980763726284n,
                4706539374333453611370871310272906412651633111294392668226252198982372846324n,
            ],
            [
                4931415214415797016210444707986521039263270801914587984123419292259499277160n,
                6988657263078170402537509816874598318402282044107987160758020550057166654636n,
            ],
        ],
        encryptedMessageHash:
            8542883023804524302520967341163415174749914671394579999616476647753350655039n,
    };

    describe('Valid input signals', function () {
        it('should compute valid witness for non zero input tx', async () => {
            const wtns = await dataEscrowElGamalEncryption.calculateWitness(
                input,
                true,
            );

            const wtnsFormattedOutput = [
                0,
                wtns[860],
                wtns[861],
                wtns[862],
                wtns[863],
                wtns[864],
                wtns[865],
                wtns[866],
                wtns[867],
                wtns[868],
                wtns[869],
                wtns[870],
                wtns[871],
                wtns[872],
                wtns[873],
                wtns[874],
                wtns[875],
                wtns[876],
                wtns[877],
                wtns[878],
                wtns[879],
                wtns[880],
                wtns[881],
                wtns[882],
                wtns[883],
                wtns[884],
            ];

            await dataEscrowElGamalEncryption.assertOut(
                wtnsFormattedOutput,
                output,
            );
            console.log('Witness calculation successful!');
        });
    });
});
