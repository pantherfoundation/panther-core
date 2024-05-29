import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const zccount_registration_wasm_file_path = path.join(
    opts.basedir,
    './compiled/zAccountRegistration/circuits.wasm',
);

const zccount_registration_witness = path.join(
    opts.basedir,
    './compiled/generate_witness.js',
);

const proving_key_path = path.join(
    opts.basedir,
    './compiled/zAccountRegistration/provingKey.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/zAccountRegistration/verificationKey.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(
        input,
        zccount_registration_wasm_file_path,
        zccount_registration_witness,
        null,
    );
    const prove = await groth16.prove(
        proving_key_path,
        zccount_registration_witness,
        null,
    );

    const proof = prove.proof;
    const publicSignals = prove.publicSignals;

    return {proof, publicSignals};
};

export const verifyProof = async (proof: any, publicSignals: any) => {
    const verificationKeyJSON = require(verification_key_path);
    const verifyResult = await groth16.verify(
        verificationKeyJSON,
        publicSignals,
        proof,
        null,
    );

    if (verifyResult === true) {
        return 'Proof Verified!';
    } else {
        return 'Invalid Proof!!';
    }
};

// =========================USAGE FROM DAPP SIDE======================================
// Input data for different type of tx (deposit, withdraw, internal tx)
let data = {};

const zeroInputForZAccountRegistration = {
    // external data anchoring
    extraInputsHash: BigInt(0n),

    // zkp amounts (not scaled)
    addedAmountZkp: BigInt(0n),

    // protocol + relayer fee in ZKP
    chargedAmountZkp: BigInt(0n),

    // zAsset
    zAssetId: BigInt(0n),
    zAssetToken: BigInt(0n),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(0n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(0n),
    zAssetScale: BigInt(1n),
    zAssetMerkleRoot: BigInt(0n),
    zAssetPathIndices: [
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

    // zAccount
    zAccountId: BigInt(0n),
    zAccountZkpAmount: BigInt(0n),
    zAccountPrpAmount: BigInt(0n),
    zAccountZoneId: BigInt(0n),
    zAccountNetworkId: BigInt(0n),
    zAccountExpiryTime: BigInt(0n),
    zAccountNonce: BigInt(0n),
    zAccountTotalAmountPerTimePeriod: BigInt(0n),
    zAccountCreateTime: BigInt(0n),
    zAccountRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountReadPubKey: [BigInt(0n), BigInt(1n)],
    zAccountNullifierPubKey: [BigInt(0n), BigInt(1n)],
    zAccountMasterEOA: BigInt(0n),
    zAccountRootSpendPrivKey: BigInt(0n),
    zAccountReadPrivKey: BigInt(0n),
    zAccountNullifierPrivKey: BigInt(0n),
    zAccountSpendKeyRandom: BigInt(0n),
    zAccountNullifier: BigInt(0n),
    zAccountCommitment: BigInt(0n),

    // blacklist merkle tree & proof of non-inclusion - zAccountId is the index-path
    zAccountBlackListLeaf: BigInt(0n),
    zAccountBlackListMerkleRoot: BigInt(0n),
    zAccountBlackListPathElements: [
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

    // zZone
    zZoneOriginZoneIDs: BigInt(0n),
    zZoneTargetZoneIDs: BigInt(0n),
    zZoneNetworkIDsBitMap: BigInt(0n),
    zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: BigInt(0n),
    zZoneKycExpiryTime: BigInt(0n),
    zZoneKytExpiryTime: BigInt(0n),
    zZoneDepositMaxAmount: BigInt(0n),
    zZoneWithrawMaxAmount: BigInt(0n),
    zZoneInternalMaxAmount: BigInt(0n),
    zZoneMerkleRoot: BigInt(0n),
    zZonePathElements: [
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
    zZonePathIndices: [
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
    zZoneEdDsaPubKey: [BigInt(0n), BigInt(0n)],
    zZoneZAccountIDsBlackList: BigInt(
        '1766847064778384329583297500742918515827483896875618958121606201292619775',
    ),
    zZoneMaximumAmountPerTimePeriod: BigInt(0n),
    zZoneTimePeriodPerMaximumAmount: BigInt(0n),

    // KYC
    kycEdDsaPubKey: [BigInt(0n), BigInt(0n)],
    kycEdDsaPubKeyExpiryTime: BigInt(0n),
    trustProvidersMerkleRoot: BigInt(0n),
    kycPathElements: [
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
    kycPathIndices: [
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
    kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),
    // signed message
    kycSignedMessagePackageType: BigInt(1n), // MUST be 1 - pkg type of KYC is always 1
    kycSignedMessageTimestamp: BigInt(0n),
    kycSignedMessageSender: BigInt(0n),
    kycSignedMessageReceiver: BigInt(0n),
    kycSignedMessageSessionId: BigInt(0n),
    kycSignedMessageRuleId: BigInt(0n),
    kycSignedMessageSigner: BigInt(0n),
    kycSignedMessageHash: BigInt(0n),
    kycSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],

    // zNetworks tree
    // network parameters:
    // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
    // 2) network-id - 6 bit
    // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
    // 4) daoDataEscrowPubKey[2]
    zNetworkId: BigInt(0n),
    zNetworkChainId: BigInt(0n),
    zNetworkIDsBitMap: BigInt(0n),
    zNetworkTreeMerkleRoot: BigInt(0n),
    zNetworkTreePathElements: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],
    zNetworkTreePathIndices: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],
    daoDataEscrowPubKey: [BigInt(0n), BigInt(0n)],
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(0n),
    forDepositReward: BigInt(0n),

    // static tree merkle root
    // Poseidon of:
    // 1) zAssetMerkleRoot
    // 2) zAccountBlackListMerkleRoot
    // 3) zNetworkTreeMerkleRoot
    // 4) zZoneMerkleRoot
    // 5) kycKytMerkleRoot
    staticTreeMerkleRoot: BigInt(0n),

    // forest root
    // Poseidon of:
    // 1) UTXO-Taxi-Tree   - 6 levels MT
    // 2) UTXO-Bus-Tree    - 26 levels MT
    // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
    // 4) Static-Tree
    forestMerkleRoot: BigInt(0n),
    taxiMerkleRoot: BigInt(0n),
    busMerkleRoot: BigInt(0n),
    ferryMerkleRoot: BigInt(0n),

    // salt
    salt: BigInt(0n),
    saltHash: BigInt(0n),

    // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
    magicalConstraint: BigInt(0n),
};

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
        19475268372719999722968422811919514831876197551539186448232606153745317203717n,

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
    kycSignedMessageSender: 407487970930055136132864974074225519407787604125n,
    kycSignedMessageSigner: 407487970930055136132864974074225519407787604125n,
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
    zZoneWithrawMaxAmount: 1 * 10 ** 12,
    zZoneInternalMaxAmount: 1 * 10 ** 12,
    zZoneMerkleRoot:
        9259525054892838702888137325078221513624475393849614502251135783828764533027n,
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
        16339808351986672048936670193536635492613600168986522206559067967046289908771n,
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

// zero input
// data = zeroInputForZAccountRegistration;

// non zero input
data = nonZeroInputForZAccountRegistration;

async function main() {
    // Generate proof
    const {proof, publicSignals} = await generateProof(data);
    // console.log('proof=>', proof);
    // console.log('publicSignals=>', publicSignals);

    // Verify the generated proof
    console.log(await verifyProof(proof, publicSignals));
}

// Uncomment to generate proof
/*
main()
    .then(() => process.exit(0))
    .catch(err => {
        console.log(err);
        process.exit(1);
    }); 
*/
