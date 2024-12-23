import * as path from 'path';
import {toBeHex} from 'ethers';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';

import {MerkleTree} from '@zk-kit/merkle-tree';
import assert from 'assert';

import {poseidon, eddsa} from 'circomlibjs';
import {bigIntToUint8Array, uint8ArrayToBigInt} from './helpers/utils';
import {
    generateRandom256Bits,
    moduloBabyJubSubFieldPrime,
} from '@panther-core/crypto/lib/base/field-operations';

import {
    deriveKeypairFromSeed,
    derivePubKeyFromPrivKey,
    deriveChildPubKeyFromRootPubKey,
    deriveChildPrivKeyFromRootPrivKey,
} from '@panther-core/crypto/lib/base/keypairs';

describe('ZAccount Registration - Non-Zero Input - Witness computation', async function (this: any) {
    const poseidon2or3 = (inputs: bigint[]): bigint => {
        assert(inputs.length === 3 || inputs.length === 2);
        return poseidon(inputs);
    };

    let circuit: any;
    let mainZAccountRegistrationWasm: any;
    let mainZAccountRegistrationWitness: any;

    let zAssetMerkleTree: any;
    let zAssetMerkleTreeLeaf: any;

    let zAccountBlackListMerkleTree: any;
    let zAccountBlackListMerkleTreeLeaf: any;

    let zNetworkMerkleTree: any;
    let zNetworkMerkleTreeLeaf: any;

    let kycKytMerkleTree: any;
    let kycKytMerkleTreeLeaf: any;

    let zZoneRecordMerkleTree: any;
    let zZoneRecordMerkleTreeLeaf: any;

    let taxiMerkleTree: any;
    let busMerkleTree: any;
    let ferryMerkleTree: any;

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/mainZAccountRegistrationV1.circom',
        );
        circuit = await wasm_tester(input, opts);

        mainZAccountRegistrationWasm = path.join(
            opts.basedir,
            './compiled/zAccountRegistration/circuits.wasm',
        );

        mainZAccountRegistrationWitness = path.join(
            opts.basedir,
            './compiled/generate_witness.js',
        );

        /* START ===== ZAssetMerkleTree Root Computation Reference ===== */
        // const zAssetCommitment0 = await addLeafToZAssetMerkleTree(
        //     0n,
        //     365481738974395054943628650313028055219811856521n,
        //     0n,
        //     2n,
        //     0n,
        //     20n,
        //     BigInt(10 ** 12), // 1 ZKP = 1 * 10^18 unscaled units / 1 * 10^6 scaled units
        // );
        /* END ===== ZAssetMerkleTree Root Computation Reference ===== */

        /* START ===== Root Key Generation for ZAccount ===== */
        // const seed = moduloBabyJubSubFieldPrime(generateRandom256Bits());
        const fixedSeed =
            1364957401031907147846036885962614753763820022581024524807608342937054566107n;
        const rootPrivateKey = fixedSeed;

        // Derive public keypair from the fixed seed
        const rootKeypair = deriveKeypairFromSeed(fixedSeed);
        const rootPublicKeys = rootKeypair.publicKey;

        // rootPublicKeys=> [
        //     9665449196631685092819410614052131494364846416353502155560380686439149087040n,
        //     13931233598534410991314026888239110837992015348186918500560502831191846288865n
        // ]
        // console.log('rootPublicKeys=>', rootPublicKeys);

        /*
        Derive child spending private key from root spending private key
        const deriveChildPrivKey = deriveChildPrivKeyFromRootPrivKey(
            rootPrivateKey,
            randomByZAccount,
        );
        console.log('deriveChildPrivKey=>', deriveChildPrivKey);
        156870929726825551122083882677471670183390372112846378310250647439531170967n
        */
        /* END ===== Root Key Generation for ZAccount ===== */

        /* START ===== Read Key Generation ===== */
        const fixedSeedForReadKey =
            1807143148206188134925427242927492302158087995127931582887251149414169118083n;

        // Generate seedForReadPubKey
        const readPubKeyKeypair = deriveKeypairFromSeed(fixedSeedForReadKey);
        const readPubKeys = readPubKeyKeypair.publicKey;

        // readPubKeys=> [
        //     1187405049038689339917658225106283881019816002721396510889166170461283567874n,
        //     311986042833546580202940940143769849297540181368261575540657864271112079432n
        // ]
        // console.log('readPubKeys=>', readPubKeys);
        /* END ===== Read Key Generation ===== */

        /* START ===== Nullifier Key Generation ===== */
        const fixedSeedForZAccountNullifierPubKey =
            2081961849142627796057765042284889488177156119328724687723132407819597118232n;

        // Generate seedForReadPubKey
        const zAccountNullifierPubKeyPair = deriveKeypairFromSeed(
            fixedSeedForZAccountNullifierPubKey,
        );

        const zAccountNullifierPubKeys = zAccountNullifierPubKeyPair.publicKey;

        // zAccountNullifierPubKeys=> [
        //     18636161575160505712724711689946435964943204943778681265331835661113836693938n,
        //     21369418187085352831313188453068285816400064790476280656092869887652115165947n
        // ]
        // console.log('zAccountNullifierPubKeys=>', zAccountNullifierPubKeys);
        /* END ===== Nullifier Key Generation ===== */

        /* START ===== Derive Child Spending Key ===== */
        // Deriving child spending public keys
        // Random generated by the sender
        const randomByZAccount =
            2346914846639907011573200271264141030138356202571314043957571486189990605213n;

        const derivedPublicKeys = deriveChildPubKeyFromRootPubKey(
            rootPublicKeys,
            randomByZAccount,
        );

        // derivedPublicKeys=> [
        //     11392870440665611384223443361093186915789163355528960804496290151264150404783n,
        //     1980602838353121356011317890644718979451459814539765591254831962186205314923n
        // ]
        // console.log('derivedPublicKeys=>', derivedPublicKeys);
        /* END ===== Derive Child Key Generation ===== */

        /*  START ===== zAccountNoteHasher Computation */
        const zAccountNoteHasherHash1 = poseidon([
            derivedPublicKeys[0], // 11392870440665611384223443361093186915789163355528960804496290151264150404783n
            derivedPublicKeys[1], // 1980602838353121356011317890644718979451459814539765591254831962186205314923n
            rootPublicKeys[0], // 9665449196631685092819410614052131494364846416353502155560380686439149087040n
            rootPublicKeys[1], // 13931233598534410991314026888239110837992015348186918500560502831191846288865n
            readPubKeys[0], // 1187405049038689339917658225106283881019816002721396510889166170461283567874n
            readPubKeys[1], // 311986042833546580202940940143769849297540181368261575540657864271112079432n
            zAccountNullifierPubKeys[0], // 18636161575160505712724711689946435964943204943778681265331835661113836693938n
            zAccountNullifierPubKeys[1], // 21369418187085352831313188453068285816400064790476280656092869887652115165947n
        ]);

        // zAccountNoteHasherHash1=> 6711554919477096259525004887560501566627161696118089717271294635242605869307n
        // console.log('zAccountNoteHasherHash1=>', zAccountNoteHasherHash1);

        const zAccountNoteHash = poseidon([
            zAccountNoteHasherHash1,
            407487970930055136132864974074225519407787604125n, // masterEOA
            33, // id
            9999990000, // amountZkp
            0, // amountPrp
            1, // zoneId
            1702652400, // expiryTime
            0, // nonce
            0, // totalAmountPerTimePeriod
            1692284400, // createTime
            2, // networkId
        ]);

        // zAccountNoteHash=> 9775219500384962933792568081585395848317570806746644855790488573783186458332n
        // console.log('zAccountNoteHash=>', zAccountNoteHash);
        /*  END ===== zAccountNoteHasher Computation */

        /* START ====== zZoneMerkleTree Reference ====== */
        // const zZoneCommitment0 = await addLeafToZZoneRecordMerkleTree(
        //     1n, // zAccountZoneId
        //     BigInt(
        //         13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        //     ), // zZoneEdDsaPubKey[0]
        //     BigInt(
        //         11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        //     ), // zZoneEdDsaPubKey[1]
        //     1n, // zZoneOriginZoneIDs
        //     1n, // zZoneTargetZoneIDs
        //     5n, // zZoneNetworkIDsBitMap
        //     1577058395n, // zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList
        //     10368000n, // zZoneKycExpiryTime - 120 days
        //     86400n, // zZoneKytExpiryTime - 24 hours
        //     BigInt(1 * 10 ** 12), // zZoneDepositMaxAmount
        //     BigInt(1 * 10 ** 12), // zZoneWithrawMaxAmount
        //     BigInt(1 * 10 ** 12), // zZoneInternalMaxAmount
        //     BigInt(
        //         1766847064778384329583297500742918515827483896875618958121606201292619775n,
        //     ), // zZoneZAccountIDsBlackList
        //     BigInt(1 * 10 ** 13), // zZoneMaximumAmountPerTimePeriod
        //     86400n, // zZoneTimePeriodPerMaximumAmount
        // );
        /* END ====== zZoneMerkleTree Reference ====== */

        /* START ====== zzAccountNullifierHasher computation ====== */
        const zAccountNullifierHasher = poseidon([
            33, // zAccountId
            1, // zAccountZoneId
            2, // zAccountNetworkId
            1364957401031907147846036885962614753763820022581024524807608342937054566107n, // zAccountRootSpendPrivKey
        ]);

        // 1139970853508650176055884485279872020247472882439797101307093417665748942631n
        // console.log("zAccountNullifierHasher=>",zAccountNullifierHasher);

        /* END ====== zAccountNullifierHasher computation ====== */

        /* START ========== ZAccountBlackListMerkleTree ========== */
        // empty - all leafs in this 16-levels tree are 0
        /* END ========== ZAccountBlackListMerkleTree ========== */

        /* START ========== KycKytMerkleTree root computation Reference ========== */
        // private key - purefi
        const prvKey = Buffer.from(
            '0001020304050607080900010203040506070809000102030405060708090001',
            'hex',
        );

        const pubKey = eddsa.prv2pub(prvKey);
        // 13277427435165878497778222415993513565335242147425444199013288855685581939618n
        const kycEdDsaPubKey0 = pubKey[0];

        // 13622229784656158136036771217484571176836296686641868549125388198837476602820n
        const kycEdDsaPubKey1 = pubKey[1];

        // Safe Operator's public key (for encryption)
        // 6461944716578528228684977568060282675957977975225218900939908264185798821478n,
        // 6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        // 1735689600n
        /* END ========== KycKytMerkleTree ========== */

        /* START ========== kycSignedMessageHashInternal calculation ========== */
        const kycSignedMessagePackageType = 1; // MUST 1 for KYC
        // Assuming the user will complete KYC verification for his ZAccount after 24 hours of ZAccount creation
        // 1687402810 < kycSignedMessageTimestamp
        // 1687489200 - Fri Jun 23 2023 03:00:00 GMT+0000
        const kycSignedMessageTimestamp = 1687489200;

        const kycSignedMessageSender =
            407487970930055136132864974074225519407787604125n;
        const kycSignedMessageSigner =
            407487970930055136132864974074225519407787604125n;
        const kycSignedMessageReceiver = 0;
        const kycSignedMessageSessionId = toBeHex(1_000_000);
        const kycSignedMessageRuleId = 91;

        const sessionId = uint8ArrayToBigInt(
            bigIntToUint8Array(BigInt(kycSignedMessageSessionId), 32).slice(
                0,
                31,
            ),
        );
        // console.log('sessionId=>', sessionId); 3906n

        const kycSignedMessageHashInternal = poseidon([
            kycSignedMessagePackageType,
            kycSignedMessageTimestamp,
            kycSignedMessageSender,
            kycSignedMessageReceiver,
            sessionId,
            kycSignedMessageRuleId,
            kycSignedMessageSigner,
        ]);

        // 5661532785846654761449575403229102333505550309557882408602178839516031482757n
        // console.log(
        //     'kycSignedMessageHashInternal=>',
        //     kycSignedMessageHashInternal,
        // );

        const signature = eddsa.signPoseidon(
            prvKey,
            kycSignedMessageHashInternal,
        );

        // signature=> {
        //     R8: [
        //       11019469704926125664550728735213125647501490479460797831114453229899757579689n,
        //       13854963995377807573540546718176146863402996159127153864764353046667588731001n
        //     ],
        //     S: 2121005999002044499564841405347448402555587723184039422438334688521918381259n
        //   }
        // console.log('signature=>', signature);
        /* END ========== kycSignedMessageHashInternal calculator ========== */

        /* START ========== zNetworkMerkleTree root computation reference ========== */
        // const zNetworkCommitment0 = await addLeafTozNetworkMerkleTree(
        //     1,
        //     5n,
        //     0,
        //     5n,
        //     10n,
        //     1828n,
        //     57646075n,
        //     BigInt(
        //         6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        //     ),
        //     BigInt(
        //         12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        //     ),
        // );
        // const zNetworkCommitment1 = await addLeafTozNetworkMerkleTree(
        //     1,
        //     80001n,
        //     2,
        //     5n,
        //     10n,
        //     1828n,
        //     57646075n,
        //     BigInt(
        //         6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        //     ),
        //     BigInt(
        //         12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        //     ),
        // );
        /* START ========== zNetworkMerkleTree root computation reference ========== */

        /* START ========== static-merkle-root calculation ========== */
        const zAssetMerkleRoot =
            19475268372719999722968422811919514831876197551539186448232606153745317203717n;

        const zAccountBlackListMerkleRoot =
            19217088683336594659449020493828377907203207941212636669271704950158751593251n;

        const zNetworkTreeMerkleRoot =
            21448888980709764146265348599357914296432058767851940011937843763756766907579n;

        const zZoneMerkleRoot =
            14189511324259672403799169204478898082389936563693111126414306380356116434465n;

        const kycKytMerkleRoot =
            675413191976636849763056983375622181122390331630387511499559599588194530856n;

        const staticTreeMerkleRoot = poseidon([
            zAssetMerkleRoot,
            zAccountBlackListMerkleRoot,
            zNetworkTreeMerkleRoot,
            zZoneMerkleRoot,
            kycKytMerkleRoot,
        ]);
        // 17931067957218291153823825912158291535579397890455292055678506728658508421915n
        // console.log('staticTreeMerkleRoot=>', staticTreeMerkleRoot);
        /* END ========== static-merkle-root calculation ========== */

        /* START ========== utxo merkle tree calculation ========== */
        // 1) UTXO-Taxi-Tree   - 6 levels MT
        // 2) UTXO-Bus-Tree    - 26 levels MT
        // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
        // considering zAccount registration is first of the tx, and UTXO trees are not populated yet, we will have a empty taxi, bus and ferry trees.
        taxiMerkleTree = new MerkleTree(poseidon2or3, 6, BigInt(0));
        // 20775607673010627194014556968476266066927294572720319469184847051418138353016n
        // console.log('taxiUTXOMerkleTree root=>', taxiMerkleTree.root);

        busMerkleTree = new MerkleTree(poseidon2or3, 26, BigInt(0));
        // 8163447297445169709687354538480474434591144168767135863541048304198280615192n
        // console.log('busUTXOMerkleTree root=>', busMerkleTree.root);

        ferryMerkleTree = new MerkleTree(poseidon2or3, 32, BigInt(0));
        // 21443572485391568159800782191812935835534334817699172242223315142338162256601n
        // console.log('ferryUTXOMerkleTree root=>', ferryMerkleTree.root);

        const forestMerkleRoot = poseidon([
            taxiMerkleTree.root,
            busMerkleTree.root,
            ferryMerkleTree.root,
        ]);

        // 21495304467251291283023151902553304166900623017887043145042714688788350087799n
        // console.log('forestMerkleRoot=>', forestMerkleRoot);
        const salt = 98765;
        const saltHash = poseidon([salt]);

        // 1035379174490095295757364370441431315669465777987680425354976294595527119016n
        // console.log('saltHash=>', saltHash);
        /* END ========== utxo merkle tree calculation ========== */
    });

    const nonZeroInputForZAccountRegistration = {
        // external data anchoring
        extraInputsHash: 0n,

        // zkp amounts (not scaled)
        addedAmountZkp: 10 ** 22,
        chargedAmountZkp: 10 ** 16,

        // ZAsset membership verification
        zAssetId: 0,
        zAssetToken: 365481738974395054943628650313028055219811856521n,
        zAssetTokenId: 0,
        zAssetNetwork: 2,
        zAssetOffset: 0,
        zAssetWeight: 20,
        zAssetScale: 10 ** 12,
        zAssetMerkleRoot:
            3907962152156750334193496040045314188759069762668001420985753241607405656087n,

        zAssetPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zAssetPathElements: [
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            12455859713696229724526221339047857485467607588813434501517928769317308134556n,
        ],

        // zAccount UTXO input verification
        zAccountRootSpendPrivKey:
            1364957401031907147846036885962614753763820022581024524807608342937054566107n,

        zAccountRootSpendPubKey: [
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ],
        zAccountNullifierPubKey: [
            18636161575160505712724711689946435964943204943778681265331835661113836693938n,
            21369418187085352831313188453068285816400064790476280656092869887652115165947n,
        ],
        zAccountReadPubKey: [
            1187405049038689339917658225106283881019816002721396510889166170461283567874n,
            311986042833546580202940940143769849297540181368261575540657864271112079432n,
        ],
        zAccountSpendKeyRandom:
            2346914846639907011573200271264141030138356202571314043957571486189990605213n,
        zAccountReadPrivKey:
            1807143148206188134925427242927492302158087995127931582887251149414169118083n,
        zAccountNullifierPrivKey:
            2081961849142627796057765042284889488177156119328724687723132407819597118232n,
        zAccountMasterEOA: 407487970930055136132864974074225519407787604125n,
        zAccountId: 33,
        zAccountZkpAmount: 9999990000,
        zAccountPrpAmount: 0n,
        zAccountZoneId: 1n,
        zAccountExpiryTime: 1702652400n,
        zAccountNonce: 0n,
        zAccountTotalAmountPerTimePeriod: 0n,
        zAccountCreateTime: 1692284400n,
        zAccountNetworkId: 2n,

        zNetworkId: 2n,

        // ZAccountUtxo commitment verification
        zAccountCommitment:
            9775219500384962933792568081585395848317570806746644855790488573783186458332n,

        // ZAccount nullifier verification
        zAccountNullifier:
            1139970853508650176055884485279872020247472882439797101307093417665748942631n,

        // verify if current zAccountId is blacklisted or not!
        zAccountBlackListLeaf: 0,
        zAccountBlackListMerkleRoot:
            19217088683336594659449020493828377907203207941212636669271704950158751593251n,

        zAccountBlackListPathElements: [
            0,
            14744269619966411208579211824598458697587494354926760081771325075741142829156n,
            7423237065226347324353380772367382631490014989348495481811164164159255474657n,
            11286972368698509976183087595462810875513684078608517520839298933882497716792n,
            3607627140608796879659380071776844901612302623152076817094415224584923813162n,
            19712377064642672829441595136074946683621277828620209496774504837737984048981n,
            20775607673010627194014556968476266066927294572720319469184847051418138353016n,
            3396914609616007258851405644437304192397291162432396347162513310381425243293n,
            21551820661461729022865262380882070649935529853313286572328683688269863701601n,
            6573136701248752079028194407151022595060682063033565181951145966236778420039n,
            12413880268183407374852357075976609371175688755676981206018884971008854919922n,
            14271763308400718165336499097156975241954733520325982997864342600795471836726n,
            20066985985293572387227381049700832219069292839614107140851619262827735677018n,
            9394776414966240069580838672673694685292165040808226440647796406499139370960n,
            11331146992410411304059858900317123658895005918277453009197229807340014528524n,
            15819538789928229930262697811477882737253464456578333862691129291651619515538n,
        ],

        // KYC signature verification
        kycSignedMessagePackageType: 1,
        kycSignedMessageTimestamp: 1687489200,
        kycSignedMessageSender:
            407487970930055136132864974074225519407787604125n,
        kycSignedMessageSigner:
            407487970930055136132864974074225519407787604125n,
        kycSignedMessageChargedAmountZkp: 0,
        kycSignedMessageReceiver: 0,
        kycSignedMessageSessionId: 3906,
        kycSignedMessageRuleId: 91,
        kycSignedMessageHash:
            5661532785846654761449575403229102333505550309557882408602178839516031482757n,

        kycSignature: [
            1812000999324420728259700135438660838005897705501062460679287721161731979555n,

            4559107604430004632244280095156850697909372641433125571245690397503888093500n,

            6334572607518453922269802055781522287805808959894493783287394842907733005571n,
        ],

        // KYCEdDSA public key membership verification
        kycEdDsaPubKey: [
            13277427435165878497778222415993513565335242147425444199013288855685581939618n,

            13622229784656158136036771217484571176836296686641868549125388198837476602820n,
        ],
        kycEdDsaPubKeyExpiryTime: 1735689600,
        trustProvidersMerkleRoot:
            675413191976636849763056983375622181122390331630387511499559599588194530856n,

        kycPathElements: [
            9489899717616586094160199124420951802253527995585848778940667248421979517388n,
            15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            12455859713696229724526221339047857485467607588813434501517928769317308134556n,
        ],
        kycPathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],

        // kyc leaf-id(1) & rule(16) is allowed in zZone
        kycMerkleTreeLeafIDsAndRulesOffset: 0,

        // zZone
        zZoneOriginZoneIDs: 1,
        zZoneTargetZoneIDs: 1,
        zZoneNetworkIDsBitMap: 5,
        zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: 1577058395,
        zZoneKycExpiryTime: 10368000,
        zZoneKytExpiryTime: 86400,
        zZoneDepositMaxAmount: 1 * 10 ** 12,
        zZoneWithdrawMaxAmount: 1 * 10 ** 12,
        zZoneInternalMaxAmount: 1 * 10 ** 12,
        zZoneMerkleRoot:
            14189511324259672403799169204478898082389936563693111126414306380356116434465n,
        zZonePathElements: [
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
            15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            19603150025355661252212198237607440386334054455687766589389473805115541553727n,
            21078238521337523625806977154031988767929399923323679789427062985634312723305n,
            15530836891415741166399860451702547522959094984965127719828675838122418186767n,
            17831836427614557290431652044145414371925087626131808598362009890774438652119n,
            4465836784202878977538296341471470300441964855135851519008900812038788261656n,
            12878033372712703816810492505815415858124057351499708737135229819203122809944n,
            18307780612008914306024415546812737365063691384665843671053755584619447524447n,
            18399220794236723308907532455368503933105202479015828179801520916772962880998n,
            17997772780903759195601581429183819619412163062353143936165307874482723961709n,
            18496693394049906980893311686550786982256672525298758106045562727433199943509n,
            12455859713696229724526221339047857485467607588813434501517928769317308134556n,
        ],
        zZonePathIndices: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        zZoneEdDsaPubKey: [
            13969057660566717294144404716327056489877917779406382026042873403164748884885n,
            11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        ],
        zZoneZAccountIDsBlackList:
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        zZoneMaximumAmountPerTimePeriod: 1 * 10 ** 13,
        zZoneTimePeriodPerMaximumAmount: 86400n,
        zZoneDataEscrowPubKey: [
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ],
        zZoneSealing: 1,

        zNetworkChainId: 80001,
        zNetworkIDsBitMap: 5,
        zNetworkTreeMerkleRoot:
            21448888980709764146265348599357914296432058767851940011937843763756766907579n,

        zNetworkTreePathElements: [
            17570133518121739548964196309665064125657253468811303682702000180123719703330n,
            15915358021544645824948763611506574620607002248967455613245207713011512736724n,
            3378776220260879286502089033253596247983977280165117209776494090180287943112n,
            13332607562825133358947880930907706925768730553195841232963500270946125500492n,
            2602133270707827583410190225239044634523625207877234879733211246465561970688n,
            19603150025355661252212198237607440386334054455687766589389473805115541553727n,
        ],
        zNetworkTreePathIndices: [1, 0, 0, 0, 0, 0],
        daoDataEscrowPubKey: [
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ],
        forTxReward: 10,
        forUtxoReward: 1828,
        forDepositReward: 57646075,

        // static tree merkle root
        // Poseidon of:
        // 1) zAssetMerkleRoot
        // 2) zAccountBlackListMerkleRoot
        // 3) zNetworkTreeMerkleRoot
        // 4) zZoneMerkleRoot
        // 5) kycKytMerkleRoot
        staticTreeMerkleRoot:
            15348222720660628311446592885548915884577953917057577776988845594265385226543n,
        // forest root
        // Poseidon of:
        // 1) UTXO-Taxi-Tree   - 6 levels MT
        // 2) UTXO-Bus-Tree    - 26 levels MT
        // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
        // 4) Static-Tree
        forestMerkleRoot:
            21495304467251291283023151902553304166900623017887043145042714688788350087799n,
        taxiMerkleRoot:
            20775607673010627194014556968476266066927294572720319469184847051418138353016n,
        busMerkleRoot:
            8163447297445169709687354538480474434591144168767135863541048304198280615192n,
        ferryMerkleRoot:
            21443572485391568159800782191812935835534334817699172242223315142338162256601n,

        // salt
        salt: 98765,
        saltHash:
            1035379174490095295757364370441431315669465777987680425354976294595527119016n,
        // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
        magicalConstraint: 123456789,
    };

    it('should compute valid witness for non zero input tx', async () => {
        await wtns.calculate(
            nonZeroInputForZAccountRegistration,
            mainZAccountRegistrationWasm,
            mainZAccountRegistrationWitness,
            null,
        );
        console.log('Witness calculation successful!');
    });
});
