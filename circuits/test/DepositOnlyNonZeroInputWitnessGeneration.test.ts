import * as path from 'path';
import {toBeHex} from 'ethers';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';
import {
    deriveChildPubKeyFromRootPubKey,
    deriveChildPrivKeyFromRootPrivKey,
    deriveKeypairFromSeed,
} from '@panther-core/crypto/lib/base/keypairs';
import {
    generateRandom256Bits,
    moduloBabyJubSubFieldPrime,
} from '@panther-core/crypto/lib/base/field-operations';
import {poseidon, eddsa, babyjub} from 'circomlibjs';
import {bigIntToUint8Array, uint8ArrayToBigInt} from './helpers/utils';
import {MerkleTree} from '@zk-kit/merkle-tree';
import assert from 'assert';

describe('Main z-transaction - Non ZeroInput - Witness computation', async function (this: any) {
    const poseidon2or3 = (inputs: bigint[]): bigint => {
        assert(inputs.length === 3 || inputs.length === 2);
        return poseidon(inputs);
    };

    let circuit: any;
    let mainTxWasm: any;
    let mainTxWitness: any;

    let zAssetMerkleTree: any;
    let zAssetMerkleTreeLeaf: any;

    let kycKytMerkleTree: any;
    let kycKytMerkleTreeLeaf1: any;
    let kycKytMerkleTreeLeaf2: any;

    let zZoneRecordMerkleTree: any;
    let zZoneRecordMerkleTreeLeaf1: any;
    let zZoneRecordMerkleTreeLeaf2: any;

    this.timeout(10000000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/mainZTransactionV1.circom',
        );
        circuit = await wasm_tester(input, opts);

        mainTxWasm = path.join(
            opts.basedir,
            './compiled/zTransaction/circuits.wasm',
        );
        mainTxWitness = path.join(
            opts.basedir,
            './compiled/generate_witness.js',
        );
    });

    // zAssetMerkleTree changes because we are changing zAssetScale from 12 to 10**12
    /* ========== ZAssetMerkleTree  ========== */
    zAssetMerkleTree = new MerkleTree(
        poseidon2or3,
        16,
        BigInt(
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
        ),
    );
    // 120 bit ERC20 token has been mapped to 64 bit zAssetId
    // 64 bit ( was 160 )
    const zAsset = BigInt(0n); // MUST BE zero for ZKP (zAssetID of zZKP is ZERO)
    const token = BigInt(365481738974395054943628650313028055219811856521n);
    const tokenId = BigInt(0n);
    const network = BigInt(2n);
    const offset = BigInt(0n);
    const weight = BigInt(1n);
    const scale = BigInt(10 ** 12);

    const zAssetLeafHash = poseidon([
        zAsset,
        token,
        tokenId,
        network,
        offset,
        weight,
        scale,
    ]);
    zAssetMerkleTreeLeaf = zAssetLeafHash;
    // 8106103403972107568175625542429005001472294223222965092079950803736527126255n
    // console.log('zAssetMerkleTreeLeaf=>', zAssetMerkleTreeLeaf);
    zAssetMerkleTree.insert(zAssetMerkleTreeLeaf);

    // POE - Proof Of Existance of zAssetMerkleTreeLeaf in zAssetMerkleTree
    const poeOfzAssetLeaf = zAssetMerkleTree.createProof(0);
    // console.log('poeOfzAssetLeaf=>', poeOfzAssetLeaf);
    // poeOfzAssetLeaf=> {
    //     root: 21135153704249495390826690606677237922449975076652949796562023680187218995691n,
    //     leaf: 8106103403972107568175625542429005001472294223222965092079950803736527126255n,
    //     siblingNodes: [
    //       2896678800030780677881716886212119387589061708732637213728415628433288554509n,
    //       15915358021544645824948763611506574620607002248967455613245207713011512736724n,
    //       3378776220260879286502089033253596247983977280165117209776494090180287943112n,
    //       13332607562825133358947880930907706925768730553195841232963500270946125500492n,
    //       2602133270707827583410190225239044634523625207877234879733211246465561970688n,
    //       19603150025355661252212198237607440386334054455687766589389473805115541553727n,
    //       21078238521337523625806977154031988767929399923323679789427062985634312723305n,
    //       15530836891415741166399860451702547522959094984965127719828675838122418186767n,
    //       17831836427614557290431652044145414371925087626131808598362009890774438652119n,
    //       4465836784202878977538296341471470300441964855135851519008900812038788261656n,
    //       12878033372712703816810492505815415858124057351499708737135229819203122809944n,
    //       18307780612008914306024415546812737365063691384665843671053755584619447524447n,
    //       18399220794236723308907532455368503933105202479015828179801520916772962880998n,
    //       17997772780903759195601581429183819619412163062353143936165307874482723961709n,
    //       18496693394049906980893311686550786982256672525298758106045562727433199943509n,
    //       12455859713696229724526221339047857485467607588813434501517928769317308134556n
    //     ],
    //     path: [
    //       0, 0, 0, 0, 0, 0,
    //       0, 0, 0, 0, 0, 0,
    //       0, 0, 0, 0
    //     ]
    //   }
    /* ========== ZAssetMerkleTree  ========== */

    /* ========== utxoOutCommitment  ========== */
    // utxoOutSpendPubKeyRandom - Random generated by sender
    // Derive keys from root public keys and random
    // Random generated by the sender

    // const fixedSeedForUtxoOutRootSpendPubKey = moduloBabyJubSubFieldPrime(
    //     generateRandom256Bits(),
    // );
    // console.log(
    //     'fixedSeedForUtxoOutRootSpendPubKey=>',
    //     fixedSeedForUtxoOutRootSpendPubKey,
    // );

    // Finding utxoOutRootSpendPubKey
    // Root spend private key
    const fixedSeedForUtxoOutRootSpendPubKey =
        224342566753775030604844896511548712233375012310694326397275189362614734606n;

    // Generate seedForReadPubKey
    const utxoOutRootSpendPubKeypair = deriveKeypairFromSeed(
        fixedSeedForUtxoOutRootSpendPubKey,
    );
    const utxoOutRootSpendPubKeys = utxoOutRootSpendPubKeypair.publicKey;
    // utxoOutRootSpendPubKeys=> [
    //     1304864957088255052279925467916092883637558158234225561709528108055407774799n,
    //     7467609468752336057589018027780748881402147278661460662995098276132272114193n
    //   ]
    // console.log('utxoOutRootSpendPubKeys=>', utxoOutRootSpendPubKeys);

    const utxoOutRootSpendPrivateKey = utxoOutRootSpendPubKeypair.privateKey;
    // 224342566753775030604844896511548712233375012310694326397275189362614734606n
    // console.log('utxoOutRootSpendPrivateKey=>', utxoOutRootSpendPrivateKey);

    // const utxoOutSpendPubKeyRandom = moduloBabyJubSubFieldPrime(generateRandom256Bits());
    // 94610875299416841087047638331595192377823041951625049650587645487287023247n
    // console.log('utxoOutSpendPubKeyRandom=>', utxoOutSpendPubKeyRandom);

    const utxoOutSpendPubKeyRandom =
        94610875299416841087047638331595192377823041951625049650587645487287023247n;

    // Deriving spendPk - Spending key
    const spendPublicKeys = deriveChildPubKeyFromRootPubKey(
        [
            1304864957088255052279925467916092883637558158234225561709528108055407774799n,
            7467609468752336057589018027780748881402147278661460662995098276132272114193n,
        ],
        94610875299416841087047638331595192377823041951625049650587645487287023247n,
    );

    // console.log(
    //     'spendPublicKeys=>',
    //     spendPublicKeys,
    // );
    // spendPublicKeys=> [
    //     8747796802323238185116411156445630051451817089702762043032476988825259250399n,
    //     5654342298770161107232801536816489231287473472412457419897521094027342184203n
    //   ]
    // ===================

    // utxoOutCommitment calculation from circuit utxoNoteHasher

    const hiden_hash = poseidon([
        BigInt(
            8747796802323238185116411156445630051451817089702762043032476988825259250399n,
        ),
        BigInt(
            5654342298770161107232801536816489231287473472412457419897521094027342184203n,
        ), // spendPubKeys
        BigInt(0n), // utxoZAsset
        BigInt(33n), // zAccountUtxoInId
        BigInt(2n), // utxoOutOriginNetworkId
        BigInt(2n), // utxoOutTargetNetworkId,
        BigInt(1700020032n), // utxoOutCreateTime - Wednesday, 15 November 2023 03:47:12
        BigInt(1n), // zAccountUtxoInZoneId
        BigInt(1n), // utxoOutTargetZoneId
    ]);
    // 1847750620042521500775036804616985925576503680209655846081358844846670353122n
    // console.log('hiden_hash=>', hiden_hash);

    // BigInt(110), // utxoOutAmount
    const hasher = poseidon([BigInt(110n), hiden_hash]);
    // 13697407973190053799075504813744698033243453017138394204507709518369300064832n
    // console.log('hasher=>', hasher);
    // ==========================
    // Derive child spending private key from root spending private key
    // zAccountUtxoInSpendPrivKey from rootPrivKey
    const deriveChildPrivKey = deriveChildPrivKeyFromRootPrivKey(
        1364957401031907147846036885962614753763820022581024524807608342937054566107n,
        // ex: random for private key
        2330947425277212370453817539463162824729034812206690133672917694841149229695n,
    );

    // 862427069656991966059708194449869313346312152472849770815560202542548015678n
    // console.log('deriveChildPrivKey=>', deriveChildPrivKey);
    /* ========== utxoOutCommitment  ========== */

    /* ========== zAccountUtxoIn nullifier  ========== */
    // [9] - Verify zAccountUtxoIn nullifier
    const zAccountUtxoInNullifierHasher = poseidon([
        BigInt(
            2081961849142627796057765042284889488177156119328724687723132407819597118232n,
        ),
        BigInt(
            20753934111959939620197373452022491283879273374456256225221477995858226219663n,
        ),
    ]);
    // zAccountUtxoInNullifier
    // console.log(
    //     'zAccountUtxoInNullifierHasher=>',
    //     zAccountUtxoInNullifierHasher,
    // );
    /* ========== zAccountUtxoIn nullifier  ========== */

    /* ========== zAccountUtxoOut commitment  ========== */
    // [11] - Verify zAccountUtxoOut spend-pub-key is indeed derivation of zAccountRootSpendKey
    // const random = moduloBabyJubSubFieldPrime(
    //     generateRandom256Bits(),
    // );
    const zAccountUtxoOutSpendKeyRandom =
        1215795509656177802870041674430711702496004716229829094660171184836034819583n;

    const zAccountUtxoOutPubKeyDeriver = deriveChildPubKeyFromRootPubKey(
        [
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ],
        1215795509656177802870041674430711702496004716229829094660171184836034819583n,
    );

    // console.log('zAccountUtxoOutPubKeyDeriver=>', zAccountUtxoOutPubKeyDeriver);
    // zAccountUtxoOutPubKeyDeriver=> [
    //     8546145906299248534728498285928494228934900865357138634779883655094892658767n,
    //     16233949703698560494882186452344248221629460060630482295539300625168232480225n
    // ]

    // [12] - Verify zAccountUtxoOut commitment computation
    const hash1 = poseidon([
        BigInt(
            8546145906299248534728498285928494228934900865357138634779883655094892658767n,
        ),
        BigInt(
            16233949703698560494882186452344248221629460060630482295539300625168232480225n,
        ),
        BigInt(
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
        ),
        BigInt(
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ),
        BigInt(
            1187405049038689339917658225106283881019816002721396510889166170461283567874n,
        ),
        BigInt(
            311986042833546580202940940143769849297540181368261575540657864271112079432n,
        ),
        BigInt(
            18636161575160505712724711689946435964943204943778681265331835661113836693938n,
        ),
        BigInt(
            21369418187085352831313188453068285816400064790476280656092869887652115165947n,
        ),
    ]);

    const zAccountUtxoOutCommitment = poseidon([
        hash1,
        BigInt(407487970930055136132864974074225519407787604125n),
        BigInt(33n),
        BigInt(99999000n),
        BigInt(0n),
        BigInt(1n),
        BigInt(1702652400n),
        BigInt(3n),
        BigInt(100000110),
        BigInt(1700020032n), // same time as zAssetUTXO got created
        BigInt(2n),
    ]);
    // 17513440433113848777254602008081679391497346341511052719820313814139380482034n
    // console.log('zAccountUtxoOutCommitment=>', zAccountUtxoOutCommitment);
    /* ========== zAccountUtxoOut commitment  ========== */

    /* ========== kyt  ========== */
    const kytDepositSignedMessagePackageType = BigInt(2n); // package type for kyt is 2
    const kytDepositSignedMessageTimestamp = BigInt(1700040650n); // GMT: Wednesday, 15 November 2023 09:30:50
    // Address from which user sends token to the vault
    const kytDepositSignedMessageSender =
        BigInt(407487970930055136132864974074225519407787604125n);
    // Address of the vault proxy
    const kytDepositSignedMessageReceiver =
        BigInt(0xfdfd920f2152565e9d7b589e4e9faee6699ad4bdn);
    const kytDepositSignedMessageToken =
        BigInt(365481738974395054943628650313028055219811856521n);
    const kytSignedMessageSessionId = toBeHex(1_000_000);
    const kytDepositSignedMessageRuleId = BigInt(99n);
    const kytDepositSignedMessageAmount = BigInt(10 ** 13);
    // Who is signing the tx - From PureFi
    const kytDepositSignedMessageSigner =
        BigInt(407487970930055136132864974074225519407787604125n);

    const sessionId = uint8ArrayToBigInt(
        bigIntToUint8Array(BigInt(kytSignedMessageSessionId), 32).slice(0, 31),
    );

    // kytDepositSignedMessageHashInternal computation
    const kytDepositSignedMessageHashInternal = poseidon([
        kytDepositSignedMessagePackageType,
        kytDepositSignedMessageTimestamp,
        kytDepositSignedMessageSender,
        kytDepositSignedMessageReceiver,
        kytDepositSignedMessageToken,
        sessionId,
        kytDepositSignedMessageRuleId,
        kytDepositSignedMessageAmount,
        kytDepositSignedMessageSigner,
    ]);
    // 20466432810656053281257521680409932658078508829124240632034736408840859429581n
    // 12430652822179204049648459930173643103691412531741204627747996341696287708858n
    // console.log(
    //     'kytDepositSignedMessageHashInternal=>',
    //     kytDepositSignedMessageHashInternal,
    // );

    // Assumed value
    const prvKey = Buffer.from(
        '0102030405060708090001020304050607080900010203040506070809000102',
        'hex',
    );

    const pubKey = eddsa.prv2pub(prvKey);
    // 12245681108156315862721578421537205412164963293078065541324995831326019830563n
    const kytEdDsaPubKey0 = pubKey[0];

    // 3850804844767147361944551138681828170238733301762589784617578364038335435190n
    const kytEdDsaPubKey1 = pubKey[1];

    // console.log('kytEdDsaPubKey0=>', kytEdDsaPubKey0);
    // console.log('kytEdDsaPubKey1=>', kytEdDsaPubKey1);

    const signature = eddsa.signPoseidon(
        prvKey,
        kytDepositSignedMessageHashInternal,
    );

    // signature=> {
    //     R8: [
    //       2265391700983385700501511925907744748011622672395003165135798438764179106394n,
    //       3203146045629976864293827964582387095516496748262949749372450935680951413714n
    //     ],
    //     S: 125900651780005850449659142097177797163902083341236940535757621061776322400n
    //   }
    // console.log('signature=>', signature);

    /* ========== kyt  ========== */

    /* ========== kycKytMerkleTree  ========== */
    kycKytMerkleTree = new MerkleTree(
        poseidon2or3,
        16,
        BigInt(
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
        ),
    );

    // PureFi Issuer pubKey - this is the production values
    // kycKytMerkleTreeLeaf1 = poseidon([
    //     BigInt(
    //         9487832625653172027749782479736182284968410276712116765581383594391603612850n,
    //     ),
    //     BigInt(
    //         20341243520484112812812126668555427080517815150392255522033438580038266039458n,
    //     ),
    //     BigInt(1735689600n),
    // ]);

    // Why are we adding dummy values to the tree instead of the prod values
    // - Since we don't have the knowledge of PureFi Issuer Private key generating a signature for a tx is not possible.
    // In this testing situation we can assume a private key to sign a transaction and the public key pair to the tree.

    // kycKytMerkleTree.insert(kycKytMerkleTreeLeaf1);

    // const poeOfKycKytMerkleTreeLeaf1 = kycKytMerkleTree.createProof(0);
    // // console.log('poeOfKycKytMerkleTreeLeaf1=>', poeOfKycKytMerkleTreeLeaf1);

    // Not finalised - Dummy values
    // kytEdDsaPubKeys
    kycKytMerkleTreeLeaf1 = poseidon([
        BigInt(
            12245681108156315862721578421537205412164963293078065541324995831326019830563n,
        ),
        BigInt(
            3850804844767147361944551138681828170238733301762589784617578364038335435190n,
        ),
        BigInt(1735689600n),
    ]);

    kycKytMerkleTree.insert(kycKytMerkleTreeLeaf1);

    // const poeOfKycKytMerkleTreeLeaf1 = kycKytMerkleTree.createProof(0);
    // console.log('poeOfKycKytMerkleTreeLeaf1=>', poeOfKycKytMerkleTreeLeaf1);

    // Add another leaf to kycKytMerkleTree which is dataEscrowPubKey
    // Assumed value
    const prvKeyForDataEscrow = Buffer.from(
        '0203040506070809000102030405060708090001020304050607080900010201',
        'hex',
    );

    const pubKeyForDataEscrow = eddsa.prv2pub(prvKeyForDataEscrow);

    const dataEscrowPubKey0 = pubKeyForDataEscrow[0];
    // 17592485119740402298442532235961126081458346886620323230996242709613631809739n
    // console.log('dataEscrowPubKey0=>', dataEscrowPubKey0);

    const dataEscrowPubKey1 = pubKeyForDataEscrow[1];
    // 715747506660163706903209996741478016638661993190721237261860373407288995714n
    // console.log('dataEscrowPubKey1=>', dataEscrowPubKey1);

    kycKytMerkleTreeLeaf2 = poseidon([
        BigInt(
            17592485119740402298442532235961126081458346886620323230996242709613631809739n,
        ),
        BigInt(
            715747506660163706903209996741478016638661993190721237261860373407288995714n,
        ),
        BigInt(1735689600n),
    ]);

    kycKytMerkleTree.insert(kycKytMerkleTreeLeaf2);

    const poeOfKycKytMerkleTreeLeaf2 = kycKytMerkleTree.createProof(1);
    // console.log('dataEscrow=>', poeOfKycKytMerkleTreeLeaf2);

    const poeOfKycKytMerkleTreeLeaf1 = kycKytMerkleTree.createProof(0);
    // console.log('kycKytPureFi=>', poeOfKycKytMerkleTreeLeaf1);
    /* ========== kycKytMerkleTree  ========== */

    /* ========== dataEscrowEphimeralRandom  ========== */
    // const dataEscrowEphimeralRandom = moduloBabyJubSubFieldPrime(
    //     generateRandom256Bits(),
    // );
    // 2508770261742365048726528579942226801565607871885423400214068953869627805520n
    const dataEscrowEphimeralRandom =
        2508770261742365048726528579942226801565607871885423400214068953869627805520n;
    // console.log('daoDataEscrowEphimeralRandom=>', dataEscrowEphimeralRandom);

    // [
    //     4301916310975298895721162797900971043392040643140207582177965168853046592976n,
    //     815388028464849479935447593762613752978886104243152067307597626016673798528n
    //   ]
    // console.log(
    //     babyjub.mulPointEscalar(babyjub.Base8, dataEscrowEphimeralRandom),
    // );

    // dataEscrowEphimeralPubKeyAx and dataEscrowEphimeralPubKeyAy extraction using BabyPbk

    // =============== dataEscrowEphimeralRandom ==============

    // ======= daoDataEscrowEphimeralRandom
    // const daoDataEscrowEphimeralRandom = moduloBabyJubSubFieldPrime(
    //     generateRandom256Bits(),
    // );
    // 2486295975768183987242341265649589729082265459252889119245150374183802141273n
    // console.log('daoDataEscrowEphimeralRandom=>', daoDataEscrowEphimeralRandom);
    const daoDataEscrowEphimeralRandom =
        2486295975768183987242341265649589729082265459252889119245150374183802141273n;
    // [
    //     18172727478723733672122242648004425580927771110712257632781054272274332874233n,
    //     18696859439217809465524370245449396885627295546811556940609392448191776076084n
    //   ]
    // console.log(
    //     babyjub.mulPointEscalar(babyjub.Base8, daoDataEscrowEphimeralRandom),
    // );
    /* ========== dataEscrowEphimeralRandom  ========== */

    /* ========== zZoneRecordMerkleTree  ========== */
    // ======= zZoneRecordMerkleTree changes because zZoneKycKytMerkleTreeLeafIDsAndRulesList has changed.
    zZoneRecordMerkleTree = new MerkleTree(
        poseidon2or3,
        16,
        BigInt(
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
        ),
    );

    zZoneRecordMerkleTreeLeaf1 = poseidon([
        BigInt(1n),
        BigInt(
            1079947189093879423832572021742411110959706509214994525945407912687412115152n,
        ),
        BigInt(
            6617854811593651784376273094293148407007707755076821057553730151008062424747n,
        ),
        BigInt(1n),
        BigInt(1n),
        BigInt(3n),
        BigInt(1660944475n), // ruleid 91, leaf id 0, ruleid 99, leaf id 0 (LSB to MSB)
        BigInt(10368000n),
        BigInt(86400n),
        BigInt(5 * 10 ** 10),
        BigInt(5 * 10 ** 10),
        BigInt(5 * 10 ** 12),
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
        BigInt(5 * 10 ** 14),
        BigInt(86400n),
    ]);

    zZoneRecordMerkleTree.insert(zZoneRecordMerkleTreeLeaf1);
    // console.log(zZoneRecordMerkleTree.createProof(0));
    // ======= zZoneRecordMerkleTree changes because zZoneKycKytMerkleTreeLeafIDsAndRulesList has changed.
    /* ========== zZoneRecordMerkleTree  ========== */

    /* ========== zZoneDataEscrowEphimeralRandom  ========== */
    // const zZoneDataEscrowEphimeralRandom = moduloBabyJubSubFieldPrime(
    //     generateRandom256Bits(),
    // );
    // 790122152066676684676093302872898287841903882354339429497975929636832086290n
    // console.log('zZoneDataEscrowEphimeralRandom=>', zZoneDataEscrowEphimeralRandom);
    const zZoneDataEscrowEphimeralRandom =
        790122152066676684676093302872898287841903882354339429497975929636832086290n;

    // [
    //     8203289148254703516772267706874329469330087297928457772489392227653451244213n,
    //     19998992060707539017877331634603765261877243592349009808298088607668947098216n,
    // ];
    // console.log(
    //     babyjub.mulPointEscalar(babyjub.Base8, zZoneDataEscrowEphimeralRandom),
    // );
    /* ========== zZoneDataEscrowEphimeralRandom  ========== */

    const nonZeroInput = {
        extraInputsHash: BigInt(0n),
        // [1] - Check zAsset
        token: BigInt(365481738974395054943628650313028055219811856521n),
        tokenId: BigInt(0n),
        utxoZAsset: BigInt(0n),

        // deposit amount is non zero for deposit only tx
        // Unscaled
        depositAmount: BigInt(10 ** 13), // This is wrong, correct after bug fix.

        // withdraw amount and withdraw change is 0 for deposit only tx
        withdrawAmount: BigInt(0n),

        // will be 0 for deposit only tx
        utxoInAmount: [BigInt(0n), BigInt(0n)],

        // 1 utxo will get created as part of deposit only tx
        // Check - If deposit and split operation which will create 2 UTXO is supported by the protocol
        utxoOutAmount: [BigInt(110n), BigInt(0n)],

        // zAsset
        zAssetId: BigInt(0n),
        zAssetToken: BigInt(365481738974395054943628650313028055219811856521n),
        zAssetTokenId: BigInt(0n),
        zAssetNetwork: BigInt(2n),
        zAssetOffset: BigInt(0n),
        zAssetWeight: BigInt(1n),
        zAssetScale: BigInt(10 ** 12),
        zAssetMerkleRoot: BigInt(
            21135153704249495390826690606677237922449975076652949796562023680187218995691n, // CHANGED - previously 3723247354377620069387735695862260139005999863996254561023715046060291769010n
        ),
        zAssetPathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAssetPathElements: [
            BigInt(
                2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
        ],

        zAssetIdZkp: BigInt(0n),
        zAssetTokenZkp:
            BigInt(365481738974395054943628650313028055219811856521n),
        zAssetTokenIdZkp: BigInt(0n),
        zAssetNetworkZkp: BigInt(2n),
        zAssetOffsetZkp: BigInt(0n),
        zAssetWeightZkp: BigInt(1n),
        zAssetScaleZkp: BigInt(10 ** 12),
        zAssetPathIndexZkp: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAssetPathElementsZkp: [
            BigInt(
                2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
        ],

        forTxReward: BigInt(0n),
        forUtxoReward: BigInt(1000n),
        forDepositReward: BigInt(0n),

        // spendTime - time spent by the UTXO in MASP
        // For deposit tx it will be 0 as UTXO created has just moved to MASP.
        // Time spent by the generated UTXO in MASP would be 0
        // Review again
        spendTime: BigInt(0n),

        // These are 0 for deposit only tx
        // 1) utxoInAmount = 0
        // 2) utxoInSpendPrivKey = 0
        // 3) utxoInSpendKeyRandom = 0

        utxoInSpendPrivKey: [BigInt(0n), BigInt(0n)],
        utxoInSpendKeyRandom: [BigInt(0n), BigInt(0n)],

        // Since the input UTXO is null, other info regarding the input UTXO will be null
        utxoInOriginZoneId: [BigInt(0n), BigInt(0n)],
        utxoInOriginZoneIdOffset: [BigInt(0n), BigInt(0n)],
        utxoInOriginNetworkId: [BigInt(0n), BigInt(0n)], // Since there is no UTXO, should it be 0?
        utxoInTargetNetworkId: [BigInt(0n), BigInt(0n)],
        utxoInCreateTime: [BigInt(0n), BigInt(0n)],
        utxoInZAccountId: [BigInt(0n), BigInt(0n)], // Whether it is 0 or an actual ZAccountID that should not matter as the check will not pass.
        utxoInMerkleTreeSelector: [
            [BigInt(0n), BigInt(0n)],
            [BigInt(0n), BigInt(0n)],
        ],
        utxoInPathIndex: [
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
        ],
        utxoInPathElements: [
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
            [
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
                BigInt(0n),
            ],
        ],
        utxoInNullifier: [BigInt(0n), BigInt(0n)],

        // input 'zAccount UTXO'
        zAccountUtxoInId: BigInt(33n),
        zAccountUtxoInZkpAmount: BigInt(100000000n),
        zAccountUtxoInPrpAmount: BigInt(0n),
        zAccountUtxoInZoneId: BigInt(1n),
        zAccountUtxoInNetworkId: BigInt(2n),
        zAccountUtxoInExpiryTime: BigInt(1702652400n),
        zAccountUtxoInNonce: BigInt(2n),
        zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
        zAccountUtxoInCreateTime: BigInt(1695282515n), // creation time of ZAccount
        zAccountUtxoInRootSpendPubKey: [
            BigInt(
                9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            ),
            BigInt(
                13931233598534410991314026888239110837992015348186918500560502831191846288865n,
            ),
        ],
        zAccountUtxoInReadPubKey: [
            BigInt(
                1187405049038689339917658225106283881019816002721396510889166170461283567874n,
            ),
            BigInt(
                311986042833546580202940940143769849297540181368261575540657864271112079432n,
            ),
        ],
        zAccountUtxoInNullifierPubKey: [
            BigInt(
                18636161575160505712724711689946435964943204943778681265331835661113836693938n,
            ),
            BigInt(
                21369418187085352831313188453068285816400064790476280656092869887652115165947n,
            ),
        ],
        zAccountUtxoInMasterEOA:
            BigInt(407487970930055136132864974074225519407787604125n),
        zAccountUtxoInSpendPrivKey:
            BigInt(
                862427069656991966059708194449869313346312152472849770815560202542548015678n,
            ),
        zAccountUtxoInReadPrivKey:
            BigInt(
                1807143148206188134925427242927492302158087995127931582887251149414169118083n,
            ),
        zAccountUtxoInNullifierPrivKey:
            BigInt(
                2081961849142627796057765042284889488177156119328724687723132407819597118232n,
            ),
        zAccountUtxoInMerkleTreeSelector: [BigInt(1n), BigInt(0n)],
        zAccountUtxoInPathIndices: [
            BigInt(0n),
            BigInt(1n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAccountUtxoInPathElements: [
            BigInt(
                2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            ),
            BigInt(
                6686357876049196452243509397062844074891055917128210002486801012953357578415n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
            BigInt(
                4689866144310700684516443679096813921756239671572972966393880542662538400201n,
            ),
            BigInt(
                15369835007378492529084633432655739856631861107309342928676871259240227049033n,
            ),
            BigInt(
                11345121393552856548579926390199540849469635305183604045111689968777651956473n,
            ),
            BigInt(
                11299066061427200562963422042645343948885353762628147353062799587547441871332n,
            ),
            BigInt(
                13642291777448032365864888577168560039775015251774208221818005338405304930884n,
            ),
            BigInt(
                5990068516814370380711726420154273589568095823652643357428323105329308577610n,
            ),
            BigInt(
                3326440148296065541386325860294367616471601340115249960006624245213734239367n,
            ),
            BigInt(
                17613623862311960463347469460117166104477522402420094872382418386742059442736n,
            ),
            BigInt(
                16619835833299406266546819907603615045049052832835825671901337303713338780409n,
            ),
            BigInt(
                15002435000641955406214223423745696701460524528446564760654584364314696565951n,
            ),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zAccountUtxoInNullifier:
            BigInt(
                7704772785245415301149676680768422465524758222165002774493537393967731116219n,
            ),

        zAccountBlackListLeaf: BigInt(0n),
        zAccountBlackListMerkleRoot:
            BigInt(
                19217088683336594659449020493828377907203207941212636669271704950158751593251n,
            ),
        zAccountBlackListPathElements: [
            BigInt(0n),
            BigInt(
                14744269619966411208579211824598458697587494354926760081771325075741142829156n,
            ),
            BigInt(
                7423237065226347324353380772367382631490014989348495481811164164159255474657n,
            ),
            BigInt(
                11286972368698509976183087595462810875513684078608517520839298933882497716792n,
            ),
            BigInt(
                3607627140608796879659380071776844901612302623152076817094415224584923813162n,
            ),
            BigInt(
                19712377064642672829441595136074946683621277828620209496774504837737984048981n,
            ),
            BigInt(
                20775607673010627194014556968476266066927294572720319469184847051418138353016n,
            ),
            BigInt(
                3396914609616007258851405644437304192397291162432396347162513310381425243293n,
            ),
            BigInt(
                21551820661461729022865262380882070649935529853313286572328683688269863701601n,
            ),
            BigInt(
                6573136701248752079028194407151022595060682063033565181951145966236778420039n,
            ),
            BigInt(
                12413880268183407374852357075976609371175688755676981206018884971008854919922n,
            ),
            BigInt(
                14271763308400718165336499097156975241954733520325982997864342600795471836726n,
            ),
            BigInt(
                20066985985293572387227381049700832219069292839614107140851619262827735677018n,
            ),
            BigInt(
                9394776414966240069580838672673694685292165040808226440647796406499139370960n,
            ),
            BigInt(
                11331146992410411304059858900317123658895005918277453009197229807340014528524n,
            ),
            BigInt(
                15819538789928229930262697811477882737253464456578333862691129291651619515538n,
            ),
        ],

        // zZone
        zZoneOriginZoneIDs: BigInt(1n),
        zZoneTargetZoneIDs: BigInt(1n),
        zZoneNetworkIDsBitMap: BigInt(3n),
        zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: BigInt(1660944475n),
        zZoneKycExpiryTime: BigInt(10368000n),
        zZoneKytExpiryTime: BigInt(86400n),
        zZoneDepositMaxAmount: BigInt(50000000000n),
        zZoneWithrawMaxAmount: BigInt(50000000000n),
        zZoneInternalMaxAmount: BigInt(5000000000000n),
        zZoneMerkleRoot:
            BigInt(
                19384564799589452100745366809702637867821047559012968378287626214005691056187n,
            ),
        zZonePathElements: [
            BigInt(
                2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
        ],
        zZonePathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zZoneEdDsaPubKey: [
            BigInt(
                1079947189093879423832572021742411110959706509214994525945407912687412115152n,
            ),
            BigInt(
                6617854811593651784376273094293148407007707755076821057553730151008062424747n,
            ),
        ],

        zZoneDataEscrowEphimeralRandom:
            BigInt(
                790122152066676684676093302872898287841903882354339429497975929636832086290n,
            ),
        zZoneDataEscrowEphimeralPubKeyAx:
            BigInt(
                8203289148254703516772267706874329469330087297928457772489392227653451244213n,
            ),
        zZoneDataEscrowEphimeralPubKeyAy:
            BigInt(
                19998992060707539017877331634603765261877243592349009808298088607668947098216n,
            ),
        zZoneZAccountIDsBlackList:
            BigInt(
                1766847064778384329583297500742918515827483896875618958121606201292619775n,
            ),
        zZoneMaximumAmountPerTimePeriod: BigInt(500000000000000n),
        zZoneTimePeriodPerMaximumAmount: BigInt(86400n),

        zZoneDataEscrowEncryptedMessageAx: [
            BigInt(
                10208894804307385444241847092606995425534865322813033676657358322033422360747n,
            ),
        ],
        zZoneDataEscrowEncryptedMessageAy: [
            BigInt(
                6977348043888224949346871727243873690394841333808944923545037472442658586640n,
            ),
        ],

        kytEdDsaPubKey: [
            BigInt(
                12245681108156315862721578421537205412164963293078065541324995831326019830563n,
            ),
            BigInt(
                3850804844767147361944551138681828170238733301762589784617578364038335435190n,
            ),
        ],
        kytEdDsaPubKeyExpiryTime: BigInt(1735689600n),
        trustProvidersMerkleRoot:
            BigInt(
                17776026177656288798445738250418845073931165171909516233447108979984337123087n,
            ),
        kytPathElements: [
            BigInt(
                17016695977491387975747777387951291558575480655001270966217001764099828994492n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
        ],
        kytPathIndex: [
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        kytMerkleTreeLeafIDsAndRulesOffset: BigInt(1n),

        kytDepositSignedMessagePackageType: BigInt(2n),
        kytDepositSignedMessageTimestamp: BigInt(1700040650n),
        kytDepositSignedMessageSender:
            BigInt(407487970930055136132864974074225519407787604125n),
        kytDepositSignedMessageReceiver:
            BigInt(0xfdfd920f2152565e9d7b589e4e9faee6699ad4bdn),
        kytDepositSignedMessageToken:
            BigInt(365481738974395054943628650313028055219811856521n),
        kytDepositSignedMessageSessionId: BigInt(3906n),
        kytDepositSignedMessageRuleId: BigInt(99n),
        kytDepositSignedMessageAmount: BigInt(10 ** 13),
        kytDepositSignedMessageSigner:
            BigInt(407487970930055136132864974074225519407787604125n),
        kytDepositSignedMessageHash:
            BigInt(
                12430652822179204049648459930173643103691412531741204627747996341696287708858n,
            ),
        kytDepositSignature: [
            BigInt(
                125900651780005850449659142097177797163902083341236940535757621061776322400n,
            ),
            BigInt(
                2265391700983385700501511925907744748011622672395003165135798438764179106394n,
            ),
            BigInt(
                3203146045629976864293827964582387095516496748262949749372450935680951413714n,
            ),
        ],

        kytWithdrawSignedMessagePackageType: BigInt(2n),
        kytWithdrawSignedMessageTimestamp: BigInt(0n),
        kytWithdrawSignedMessageSender: BigInt(0n),
        kytWithdrawSignedMessageReceiver: BigInt(0n),
        kytWithdrawSignedMessageToken: BigInt(0n),
        kytWithdrawSignedMessageSessionId: BigInt(0n),
        kytWithdrawSignedMessageRuleId: BigInt(0n),
        kytWithdrawSignedMessageAmount: BigInt(0n),
        kytWithdrawSignedMessageSigner: BigInt(0n),
        kytWithdrawSignedMessageHash: BigInt(0n),
        kytWithdrawSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],

        dataEscrowPubKey: [
            BigInt(
                17592485119740402298442532235961126081458346886620323230996242709613631809739n,
            ),
            BigInt(
                715747506660163706903209996741478016638661993190721237261860373407288995714n,
            ),
        ],
        dataEscrowPubKeyExpiryTime: BigInt(1735689600n),
        dataEscrowEphimeralRandom:
            BigInt(
                2508770261742365048726528579942226801565607871885423400214068953869627805520n,
            ),
        dataEscrowEphimeralPubKeyAx:
            BigInt(
                4301916310975298895721162797900971043392040643140207582177965168853046592976n,
            ),
        dataEscrowEphimeralPubKeyAy:
            BigInt(
                815388028464849479935447593762613752978886104243152067307597626016673798528n,
            ),
        dataEscrowPathElements: [
            BigInt(
                9110636271130100699392899364881796968545308977595504989546918307235047784339n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
            BigInt(
                15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            ),
            BigInt(
                17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            ),
            BigInt(
                4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            ),
            BigInt(
                12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            ),
            BigInt(
                18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            ),
            BigInt(
                18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            ),
            BigInt(
                17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            ),
            BigInt(
                18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            ),
            BigInt(
                12455859713696229724526221339047857485467607588813434501517928769317308134556n,
            ),
        ],
        dataEscrowPathIndex: [
            BigInt(1n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],

        dataEscrowEncryptedMessageAx: [
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                8545989893275276231799888565301908912318543399332021915998096176909753199105n,
            ),
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                13712697828766315168315008673159740777226884807578482481721063613885274042245n,
            ),
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                13961837954519038829977545387763368791911867054847608369160425559810214585436n,
            ),
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                13116190464256158497839887597524501812846680459236688248532348621490241197945n,
            ),
            BigInt(
                8545989893275276231799888565301908912318543399332021915998096176909753199105n,
            ),
        ],
        dataEscrowEncryptedMessageAy: [
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                20637416069479879785001161881462675658184199290896901419191315646291334864295n,
            ),
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                921847061137674076449255978734288957915775930145159608447586708321995062081n,
            ),
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                333337179729258256745061485466138303316259798821832830250345169150710768565n,
            ),
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                20000738990158911673922080741335508851223507369672887792062131046520480743662n,
            ),
            BigInt(
                20637416069479879785001161881462675658184199290896901419191315646291334864295n,
            ),
        ],
        daoDataEscrowPubKey: [
            BigInt(
                12272087043529289524334796370800745508281317430063431496260996322077559426628n,
            ),
            BigInt(
                9194872949126287643523554866093178264045906284036198776275995684726142899669n,
            ),
        ],
        daoDataEscrowEphimeralRandom:
            BigInt(
                2486295975768183987242341265649589729082265459252889119245150374183802141273n,
            ),
        daoDataEscrowEphimeralPubKeyAx:
            BigInt(
                18172727478723733672122242648004425580927771110712257632781054272274332874233n,
            ),
        daoDataEscrowEphimeralPubKeyAy:
            BigInt(
                18696859439217809465524370245449396885627295546811556940609392448191776076084n,
            ),

        daoDataEscrowEncryptedMessageAx: [
            BigInt(
                12879739213981704288750108194714802671973445666473095895725252519271988297987n,
            ),
            BigInt(
                21833265219210485206570519125464965540312044426938621491904711178394780344784n,
            ),
            BigInt(
                2869541545429402187346283621721205631128436292716179754517298377044969775951n,
            ),
        ],
        daoDataEscrowEncryptedMessageAy: [
            BigInt(
                13772388044395714748652123630736750443686679234538591593691171912893370807102n,
            ),
            BigInt(
                20320659586003977380820659517084340668626755270558533029265994160344727877766n,
            ),
            BigInt(
                14170793440149454979315487076682462822637838285481952067036422789832071174254n,
            ),
        ],

        // Same timestamp is used for ZAccountUTXOOut as well.
        utxoOutCreateTime: BigInt(1700020032n), //  utxoOutCreateTime - Wednesday, 15 November 2023 03:47:12
        utxoOutOriginNetworkId: [BigInt(2n), BigInt(0n)],
        utxoOutTargetNetworkId: [BigInt(2n), BigInt(0n)],
        utxoOutTargetZoneId: [BigInt(1n), BigInt(0n)],
        utxoOutTargetZoneIdOffset: [BigInt(0n), BigInt(0n)],
        utxoOutSpendPubKeyRandom: [
            BigInt(
                94610875299416841087047638331595192377823041951625049650587645487287023247n,
            ),
            BigInt(0n),
        ],
        utxoOutRootSpendPubKey: [
            [
                BigInt(
                    1304864957088255052279925467916092883637558158234225561709528108055407774799n,
                ),
                BigInt(
                    7467609468752336057589018027780748881402147278661460662995098276132272114193n,
                ),
            ],
            [BigInt(0n), BigInt(0n)],
        ],
        utxoOutCommitment: [
            BigInt(
                13697407973190053799075504813744698033243453017138394204507709518369300064832n,
            ),
            BigInt(0n),
        ],

        zAccountUtxoOutZkpAmount: BigInt(99999000n),
        zAccountUtxoOutSpendKeyRandom:
            BigInt(
                1215795509656177802870041674430711702496004716229829094660171184836034819583n,
            ),
        zAccountUtxoOutCommitment:
            BigInt(
                17513440433113848777254602008081679391497346341511052719820313814139380482034n,
            ),
        // For better testing choosing chargedAmountZkp and donatedAmountZkp >= 10 ** 12
        chargedAmountZkp: BigInt(10 ** 15),
        donatedAmountZkp: BigInt(10 ** 14),

        zNetworkId: BigInt(2n),
        zNetworkChainId: BigInt(80001n),
        zNetworkIDsBitMap: BigInt(3n),
        zNetworkTreeMerkleRoot:
            BigInt(
                14012219796450685573713237305847642356367283250649627741328974142691321346497n,
            ),
        zNetworkTreePathIndex: [
            BigInt(1n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
            BigInt(0n),
        ],
        zNetworkTreePathElements: [
            BigInt(
                13600883386059764494059343531292624452055533199459734774067365206557455126217n,
            ),
            BigInt(
                15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            ),
            BigInt(
                3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            ),
            BigInt(
                13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            ),
            BigInt(
                2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            ),
            BigInt(
                19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            ),
        ],
        // This will change as multiple static tree details changes, hence calculated when needed
        staticTreeMerkleRoot: BigInt(0n),

        forestMerkleRoot: BigInt(0n),
        taxiMerkleRoot:
            BigInt(
                21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            ),
        busMerkleRoot:
            BigInt(
                20054720321721789130672454451485670158406441680080820519586483953899629064450n,
            ),
        ferryMerkleRoot:
            BigInt(
                16585547643065588372010718035675163508420403417446192422307560350739915741648n,
            ),

        // salt
        salt: BigInt(0n),
        saltHash: BigInt(0n),

        // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
        magicalConstraint: BigInt(0n),

        // 0 - has to be zero, it's a bug, change the value once the bug is fixed.
        depositChange: BigInt(0n),
        withdrawChange: BigInt(0n),
    };

    it('should compute valid witness for zero input deposit only tx', async () => {
        await wtns.calculate(nonZeroInput, mainTxWasm, mainTxWitness, null);
        console.log('Witness calculation successful!');
    });
});
