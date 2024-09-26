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
            20272187331257067730312283674886235862380792715978757885894576729734646287595n,
            19572432596710438943526974929308114285457955803650387518123908035938551377040n,
        ],
    };

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
    // drv_mGrY_final0=> [
    //     13448997628370172142121064540922161530131000291293757353976490406600659699485n,
    //     6786713265324802353836561761516675026132581641648269618031750582273380915074n
    //   ]
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
    // drv_mGrY_final1=> [
    //     4571540050240624494219405580583507049331981473711771943756884769018855623280n,
    //     21198610127396451809526754236892481138999958113447719990820486113837174916694n
    //   ]
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
    // drv_mGrY_final2=> [
    //     4033670544751227578052559269341339055518688085590815938396833382029764334912n,
    //     18354775240679013885485121089406497849546512162874668345566059410418709709673n
    //   ]
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
    // drv_mGrY_final3=> [
    //     20399286099278016462437314178100881060967018389578365954358985464840531062958n,
    //     16603415768633382355527893930917768290248723894235579106482928918104961601427n
    //   ]
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
    // drv_mGrY_final4=> [
    //     5465482396988413500244136121916137093725277189786903024771569541729342264602n,
    //     18052446522046943908230226084246345928969485773552410049729266016545084008699n
    //   ]
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
    // drv_mGrY_final5=> [
    //     12296015241185805645813252451366902176955110432166997758114703914076473480566n,
    //     20640217119393223723114928028264255300362752921338608507459601444462338718795n
    //   ]
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
    // drv_mGrY_final6=> [
    //     9543857838494654970399777461409295060991860277282271271366165506276941025267n,
    //     10640319856812298729186938394589122461231374039478038286491853387922985109395n
    //   ]
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
    // drv_mGrY_final7=> [
    //     16316923171052759190502076430083075231582942463614244885046756571940782113749n,
    //     8705376175596548806662826766037702236642974311830201086593732499508964520n
    //   ]
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
    // drv_mGrY_final8=> [
    //     14009366412221217138863529120356799739925282410826135633228742365215681098110n,
    //     13320090048181446201416279522323242712648198238420685144157745291106881279337n
    //   ]
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
    // drv_mGrY_final9=> [
    //     12532002519490190436214220231644858505936551570710292722418539394393539472942n,
    //     10516080860923901805925996803626947967959810157132218960043924430105688744218n
    //   ]
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
    // drv_mGrY_final10=> [
    //     10346448136845180430735982709674302600604226766160695898857955583867479620566n,
    //     1685237099490986177641221522256131190271058376455210394810325980710119110251n
    //   ]
    // console.log('drv_mGrY_final10=>', drv_mGrY_final10);
    const encryptedMessage10 = drv_mGrY_final10; // 10 - 11th element

    // encryptedMessageHash computation
    const n1 = poseidon([
        13448997628370172142121064540922161530131000291293757353976490406600659699485n,
        6786713265324802353836561761516675026132581641648269618031750582273380915074n,
        4571540050240624494219405580583507049331981473711771943756884769018855623280n,
        21198610127396451809526754236892481138999958113447719990820486113837174916694n,
        4033670544751227578052559269341339055518688085590815938396833382029764334912n,
        18354775240679013885485121089406497849546512162874668345566059410418709709673n,
        20399286099278016462437314178100881060967018389578365954358985464840531062958n,
        16603415768633382355527893930917768290248723894235579106482928918104961601427n,
        5465482396988413500244136121916137093725277189786903024771569541729342264602n,
        18052446522046943908230226084246345928969485773552410049729266016545084008699n,
        12296015241185805645813252451366902176955110432166997758114703914076473480566n,
    ]);

    const n2 = poseidon([
        20640217119393223723114928028264255300362752921338608507459601444462338718795n,
        9543857838494654970399777461409295060991860277282271271366165506276941025267n,
        10640319856812298729186938394589122461231374039478038286491853387922985109395n,
        16316923171052759190502076430083075231582942463614244885046756571940782113749n,
        8705376175596548806662826766037702236642974311830201086593732499508964520n,
        14009366412221217138863529120356799739925282410826135633228742365215681098110n,
        13320090048181446201416279522323242712648198238420685144157745291106881279337n,
        12532002519490190436214220231644858505936551570710292722418539394393539472942n,
        10516080860923901805925996803626947967959810157132218960043924430105688744218n,
        10346448136845180430735982709674302600604226766160695898857955583867479620566n,
        1685237099490986177641221522256131190271058376455210394810325980710119110251n,
    ]);

    const encryptedMessageHash = poseidon([n1, n2]);
    // encryptedMessageHash=> 16372847102543685188298636337874554532365980386692610168627065266869249284947n
    // console.log('encryptedMessageHash=>', encryptedMessageHash);

    const output = {
        ephemeralPubKey: [
            4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            815388028464849479935447593762613752978886104243152067307597626016673798528n,
        ],
        encryptedMessage: [
            [
                13448997628370172142121064540922161530131000291293757353976490406600659699485n,
                6786713265324802353836561761516675026132581641648269618031750582273380915074n,
            ],
            [
                4571540050240624494219405580583507049331981473711771943756884769018855623280n,
                21198610127396451809526754236892481138999958113447719990820486113837174916694n,
            ],
            [
                4033670544751227578052559269341339055518688085590815938396833382029764334912n,
                18354775240679013885485121089406497849546512162874668345566059410418709709673n,
            ],
            [
                20399286099278016462437314178100881060967018389578365954358985464840531062958n,
                16603415768633382355527893930917768290248723894235579106482928918104961601427n,
            ],
            [
                5465482396988413500244136121916137093725277189786903024771569541729342264602n,
                18052446522046943908230226084246345928969485773552410049729266016545084008699n,
            ],
            [
                12296015241185805645813252451366902176955110432166997758114703914076473480566n,
                20640217119393223723114928028264255300362752921338608507459601444462338718795n,
            ],
            [
                9543857838494654970399777461409295060991860277282271271366165506276941025267n,
                10640319856812298729186938394589122461231374039478038286491853387922985109395n,
            ],
            [
                16316923171052759190502076430083075231582942463614244885046756571940782113749n,
                8705376175596548806662826766037702236642974311830201086593732499508964520n,
            ],
            [
                14009366412221217138863529120356799739925282410826135633228742365215681098110n,
                13320090048181446201416279522323242712648198238420685144157745291106881279337n,
            ],
            [
                12532002519490190436214220231644858505936551570710292722418539394393539472942n,
                10516080860923901805925996803626947967959810157132218960043924430105688744218n,
            ],
            [
                10346448136845180430735982709674302600604226766160695898857955583867479620566n,
                1685237099490986177641221522256131190271058376455210394810325980710119110251n,
            ],
        ],
        encryptedMessageHash:
            16372847102543685188298636337874554532365980386692610168627065266869249284947n,
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
