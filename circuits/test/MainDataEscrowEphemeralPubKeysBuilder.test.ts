import * as path from 'path';

import cicom_wasm_tester from 'circom_tester';
const wasm_tester = cicom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {babyjub, poseidon} from 'circomlibjs';

describe('EphemeralPubKeysBuilder circuit', function (this: any) {
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

    // Taking this value ephemeralRandom and pubKey to be in sync with the integration tests
    // ephemeralRandom0
    const ephemeralRandom =
        2508770261742365048726528579942226801565607871885423400214068953869627805520n;

    const pubKey = [
        6461944716578528228684977568060282675957977975225218900939908264185798821478n,
        6315516704806822012759516718356378665240592543978605015143731597167737293922n,
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

    // ephemeralRandom1 - 1
    const ephemeralRandom1Poseidon = poseidon([
        sharedPubKey0[0],
        sharedPubKey0[1],
    ]);
    const ephemeralRandom1 = BigInt(
        '0b' +
            ephemeralRandom1Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom1=>', ephemeralRandom1);

    // sharedPubKey1 - [1,0] & [1,1]
    const sharedPubKey1 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom1.toString(),
    );
    // console.log('sharedPubKey1=>', sharedPubKey1);

    // ephemeralPubKey1 - [1,0] & [1,1]
    const ephemeralPubKey1 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom1,
    );
    // console.log('ephemeralPubKey1=>', ephemeralPubKey1);

    // ephemeralRandom2 - 2
    const ephemeralRandom2Poseidon = poseidon([
        sharedPubKey1[0],
        sharedPubKey1[1],
    ]);
    let ephemeralRandom2 = BigInt(
        '0b' +
            ephemeralRandom2Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom2=>', ephemeralRandom2);

    // sharedPubKey2 - [2,0] & [2,1]
    const sharedPubKey2 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom2.toString(),
    );
    // console.log('sharedPubKey2=>', sharedPubKey2);

    // ephemeralPubKey2 - [2,0] & [2,1]
    const ephemeralPubKey2 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom2,
    );
    // console.log('ephemeralPubKey2=>', ephemeralPubKey2);

    // ephemeralRandom3 - 3
    const ephemeralRandom3Poseidon = poseidon([
        sharedPubKey2[0],
        sharedPubKey2[1],
    ]);
    let ephemeralRandom3 = BigInt(
        '0b' +
            ephemeralRandom3Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom3=>', ephemeralRandom3);

    // sharedPubKey3 - [3,0] & [3,1]
    const sharedPubKey3 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom3.toString(),
    );
    // console.log('sharedPubKey3=>', sharedPubKey3);

    // ephemeralPubKey3 - [3,0] & [3,1]
    const ephemeralPubKey3 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom3,
    );
    // console.log('ephemeralPubKey3=>', ephemeralPubKey3);

    // ephemeralRandom4 - 4
    const ephemeralRandom4Poseidon = poseidon([
        sharedPubKey3[0],
        sharedPubKey3[1],
    ]);
    let ephemeralRandom4 = BigInt(
        '0b' +
            ephemeralRandom4Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom4=>', ephemeralRandom4);

    // sharedPubKey4 - [4,0] & [4,1]
    const sharedPubKey4 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom4.toString(),
    );
    // console.log('sharedPubKey4=>', sharedPubKey4);

    // ephemeralPubKey4 - [4,0] & [4,1]
    const ephemeralPubKey4 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom4,
    );
    // console.log('ephemeralPubKey4=>', ephemeralPubKey4);

    // ephemeralRandom5 - 5
    const ephemeralRandom5Poseidon = poseidon([
        sharedPubKey4[0],
        sharedPubKey4[1],
    ]);
    let ephemeralRandom5 = BigInt(
        '0b' +
            ephemeralRandom5Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom5=>', ephemeralRandom5);

    // sharedPubKey5 - [5,0] & [5,1]
    const sharedPubKey5 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom5.toString(),
    );
    // console.log('sharedPubKey5=>', sharedPubKey5);

    // ephemeralPubKey4 - [5,0] & [5,1]
    const ephemeralPubKey5 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom5,
    );
    // console.log('ephemeralPubKey5=>', ephemeralPubKey5);

    // ephemeralRandom6 - 6
    const ephemeralRandom6Poseidon = poseidon([
        sharedPubKey5[0],
        sharedPubKey5[1],
    ]);
    let ephemeralRandom6 = BigInt(
        '0b' +
            ephemeralRandom6Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom6=>', ephemeralRandom6);

    // sharedPubKey6 - [6,0] & [6,1]
    const sharedPubKey6 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom6.toString(),
    );
    // console.log('sharedPubKey6=>', sharedPubKey6);

    // ephemeralPubKey6 - [6,0] & [6,1]
    const ephemeralPubKey6 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom6,
    );
    // console.log('ephemeralPubKey6=>', ephemeralPubKey6);

    // ephemeralRandom7 - 7
    const ephemeralRandom7Poseidon = poseidon([
        sharedPubKey6[0],
        sharedPubKey6[1],
    ]);
    let ephemeralRandom7 = BigInt(
        '0b' +
            ephemeralRandom7Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom7=>', ephemeralRandom7);

    // sharedPubKey7 - [7,0] & [7,1]
    const sharedPubKey7 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom7.toString(),
    );
    // console.log('sharedPubKey7=>', sharedPubKey7);

    // ephemeralPubKey7 - [7,0] & [7,1]
    const ephemeralPubKey7 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom7,
    );
    // console.log('ephemeralPubKey7=>', ephemeralPubKey7);

    // ephemeralRandom8 - 8
    const ephemeralRandom8Poseidon = poseidon([
        sharedPubKey7[0],
        sharedPubKey7[1],
    ]);
    let ephemeralRandom8 = BigInt(
        '0b' +
            ephemeralRandom8Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom8=>', ephemeralRandom8);

    // sharedPubKey8 - [8,0] & [8,1]
    const sharedPubKey8 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom8.toString(),
    );
    // console.log('sharedPubKey8=>', sharedPubKey8);

    // ephemeralPubKey8 - [8,0] & [8,1]
    const ephemeralPubKey8 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom8,
    );
    // console.log('ephemeralPubKey8=>', ephemeralPubKey8);

    // ephemeralRandom9 - 9
    const ephemeralRandom9Poseidon = poseidon([
        sharedPubKey8[0],
        sharedPubKey8[1],
    ]);
    let ephemeralRandom9 = BigInt(
        '0b' +
            ephemeralRandom9Poseidon.toString(2).padStart(252, '0').slice(-252),
    );
    // console.log('ephemeralRandom9=>', ephemeralRandom9);

    // sharedPubKey9 - [9,0] & [9,1]
    const sharedPubKey9 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom9.toString(),
    );
    // console.log('sharedPubKey9=>', sharedPubKey9);

    // ephemeralPubKey9 - [9,0] & [9,1]
    const ephemeralPubKey9 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom9,
    );
    // console.log('ephemeralPubKey9=>', ephemeralPubKey9);

    // ephemeralRandom10 - 10
    const ephemeralRandom10Poseidon = poseidon([
        sharedPubKey9[0],
        sharedPubKey9[1],
    ]);
    let ephemeralRandom10 = BigInt(
        '0b' +
            ephemeralRandom10Poseidon
                .toString(2)
                .padStart(252, '0')
                .slice(-252),
    );
    // console.log('ephemeralRandom10=>', ephemeralRandom10);

    // sharedPubKey10 - [10,0] & [10,1]
    const sharedPubKey10 = babyjub.mulPointEscalar(
        pubKey,
        ephemeralRandom10.toString(),
    );
    // console.log('sharedPubKey10=>', sharedPubKey10);

    // ephemeralPubKey10 - [10,0] & [10,1]
    const ephemeralPubKey10 = babyjub.mulPointEscalar(
        babyjub.Base8,
        ephemeralRandom10,
    );
    // console.log('ephemeralPubKey10=>', ephemeralPubKey10);

    // hidden point computation
    const hiddenPoint_poseidon_out = poseidon([
        12871439135712262058001002684440962908819002983015508623206745248194094676428n,
        17114886397516225242214463605558970802516242403903915116207133292790211059315n,
    ]);

    let mask = (BigInt(1) << BigInt(252)) - BigInt(1);
    let hiddenPoint252Bits = BigInt(hiddenPoint_poseidon_out) & mask;

    const hiddenPoint_eMult = babyjub.mulPointEscalar(
        pubKey,
        hiddenPoint252Bits,
    );
    // console.log('hiddenPoint_eMult=>', hiddenPoint_eMult);

    const input = {
        pubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
        ephemeralRandom:
            2508770261742365048726528579942226801565607871885423400214068953869627805520n,
    };

    const output = {
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
