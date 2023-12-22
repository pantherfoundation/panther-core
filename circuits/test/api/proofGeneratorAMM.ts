import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const amm_wasm_file_path = path.join(
    opts.basedir,
    './compiled/prpConverter/circuits.wasm',
);

const amm_witness = path.join(opts.basedir, './compiled/generateWitness.js');

const proving_key_path = path.join(
    opts.basedir,
    './compiled/prpConverter/provingKey.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/prpConverter/verificationKey.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(input, amm_wasm_file_path, amm_witness, null);
    const prove = await groth16.prove(proving_key_path, amm_witness, null);

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
let data = {};

const zeroInput = {
    // external data anchoring
    extraInputsHash: BigInt(0n),

    chargedAmountZkp: BigInt(0n),
    createTime: BigInt(0n),
    depositAmountPrp: BigInt(0n),
    withdrawAmountPrp: BigInt(0n),

    utxoCommitment: BigInt(0n),
    utxoSpendPubKey: [BigInt(0n), BigInt(1n)],
    utxoSpendKeyRandom: BigInt(0n),

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

    zAccountUtxoInId: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(0n),
    zAccountUtxoInPrpAmount: BigInt(0n),
    zAccountUtxoInZoneId: BigInt(0n),
    zAccountUtxoInNetworkId: BigInt(0n),
    zAccountUtxoInExpiryTime: BigInt(0n),
    zAccountUtxoInNonce: BigInt(0n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(0n),
    zAccountUtxoInRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountUtxoInReadPubKey:[BigInt(0n), BigInt(1n)],
    zAccountUtxoInNullifierPubKey:[BigInt(0n), BigInt(1n)],
    zAccountUtxoInSpendPrivKey: BigInt(0n),
    zAccountUtxoInNullifierPrivKey:BigInt(0n),
    zAccountUtxoInMasterEOA: BigInt(0n),
    zAccountUtxoInSpendKeyRandom: BigInt(0n),
    zAccountUtxoInCommitment: BigInt(0n),
    zAccountUtxoInNullifier: BigInt(0n),
    zAccountUtxoInMerkleTreeSelector: [BigInt(1n), BigInt(0n)],
    zAccountUtxoInPathIndices: [
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
    zAccountUtxoInPathElements: [
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

    zAccountUtxoOutZkpAmount: BigInt(0n),
    zAccountUtxoOutPrpAmount: BigInt(0n),
    zAccountUtxoOutSpendKeyRandom: BigInt(0n),
    zAccountUtxoOutCommitment: BigInt(0n),

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

    trustProvidersMerkleRoot: BigInt(0n),
    staticTreeMerkleRoot: BigInt(0n),
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

const nonZeroInputVoucherExchange = {
    // external data anchoring
    extraInputsHash: BigInt(0n),

    // zAsset
    zAssetId: BigInt(0n),
    zAssetToken: BigInt(365481738974395054943628650313028055219811856521n),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(2n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(1n),
    zAssetScale: BigInt(12n),
    zAssetMerkleRoot:
        BigInt(
            3723247354377620069387735695862260139005999863996254561023715046060291769010n,
        ),
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

    chargedAmountZkp: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(100000000n),
    zAccountUtxoOutZkpAmount: BigInt(100000000n),

    zAccountUtxoInRootSpendPubKey: [
        BigInt(
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
        ),
        BigInt(
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ),
    ],
    zAccountUtxoInSpendKeyRandom:
        BigInt(
            2346914846639907011573200271264141030138356202571314043957571486189990605213n,
        ),
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
    zAccountUtxoInNullifierPrivKey:
        BigInt(
            2081961849142627796057765042284889488177156119328724687723132407819597118232n,
        ),
    zAccountUtxoInMasterEOA:
        BigInt(407487970930055136132864974074225519407787604125n),
    zAccountUtxoInId: BigInt(33n),
    zAccountUtxoInPrpAmount: BigInt(0n),
    zAccountUtxoInZoneId: BigInt(1n),
    zAccountUtxoInExpiryTime: BigInt(1702652400n),
    zAccountUtxoInNonce: BigInt(0n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(1692284400n),
    zAccountUtxoInNetworkId: BigInt(2n),

    zAccountUtxoInCommitment:
        BigInt(
            19047992597093047336371215524754541878461093335047259582748851115004307254010n,
        ),
    zNetworkId: BigInt(2n),

    // Claimed voucher(vouchers) balance
    depositAmountPrp: BigInt(500n),

    // For Voucher Exchange withdrawal of PRP is 0
    withdrawAmountPrp: BigInt(0n),
    zAccountUtxoOutPrpAmount: BigInt(500n),

    zAccountUtxoInSpendPrivKey:
        BigInt(
            1364957401031907147846036885962614753763820022581024524807608342937054566107n,
        ),

    zAccountUtxoInNullifier:
        BigInt(
            14914857781069603067364359915237089909255680140753506997126505326724192453553n,
        ),
    zAccountUtxoInMerkleTreeSelector: [BigInt(1n), BigInt(0n)],
    zAccountUtxoInPathIndices: [
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
    zAccountUtxoInPathElements: [
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
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
    ],

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
    // ------
    zAccountUtxoOutSpendKeyRandom:
        BigInt(
            185557730709061450306117592388043477299652441972445952549541952981196070710n,
        ),
    zAccountUtxoOutCommitment:
        BigInt(
            883577885029992475849474167057954109513915827487763736646723184112542450368n,
        ),

    // GMT: Tuesday, 29 August 2023 10:49:12
    createTime: BigInt(1693306152n),

    utxoCommitment:
        BigInt(
            19593108235650878637893509278693460179257795305603387070719951077607152456245n,
        ),
    // Will be 0 as no ZAssetUTXO gets created during AMM voucher exchange tx
    utxoSpendPubKey: [BigInt(0), BigInt(1)],
    utxoSpendKeyRandom: BigInt(0),

    zZoneOriginZoneIDs: BigInt(1n),
    zZoneTargetZoneIDs: BigInt(1n),
    zZoneNetworkIDsBitMap: BigInt(3n),
    zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: BigInt(91n),
    zZoneKycExpiryTime: BigInt(10368000n), // 1 week epoch time
    zZoneKytExpiryTime: BigInt(86400n),
    zZoneDepositMaxAmount: BigInt(5 * 10 ** 10),
    zZoneWithrawMaxAmount: BigInt(5 * 10 ** 10),
    zZoneInternalMaxAmount: BigInt(5 * 10 ** 12),
    zZoneMerkleRoot:
        BigInt(
            2768686232753548194788154003002220124197365245281377680762459495658913308970n,
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
    zZoneEdDsaPubKey: [
        BigInt(
            1079947189093879423832572021742411110959706509214994525945407912687412115152n,
        ),
        BigInt(
            6617854811593651784376273094293148407007707755076821057553730151008062424747n,
        ),
    ],
    zZoneZAccountIDsBlackList:
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
    zZoneMaximumAmountPerTimePeriod: BigInt(5 * 10 ** 14),
    zZoneTimePeriodPerMaximumAmount: BigInt(86400n),

    zNetworkChainId: BigInt(80001n),
    zNetworkIDsBitMap: BigInt(3n),
    zNetworkTreeMerkleRoot:
        BigInt(
            14012219796450685573713237305847642356367283250649627741328974142691321346497n,
        ),
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
    zNetworkTreePathIndices: [
        BigInt(1n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],
    daoDataEscrowPubKey: [
        BigInt(
            12272087043529289524334796370800745508281317430063431496260996322077559426628n,
        ),
        BigInt(
            9194872949126287643523554866093178264045906284036198776275995684726142899669n,
        ),
    ],
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(1000n),
    forDepositReward: BigInt(0n),

    trustProvidersMerkleRoot:
        BigInt(
            17322022431886165400149810602305622216747412620247038711546582810646517935323n,
        ),
    staticTreeMerkleRoot:
        BigInt(
            15323795652282733476787593554593633163509524267163105218965028724899034265607n,
        ),
    forestMerkleRoot:
        BigInt(
            12897872365987969151721335753320186442032465800886375827505461281090841127745n,
        ),
    taxiMerkleRoot:
        BigInt(
            21078238521337523625806977154031988767929399923323679789427062985634312723305n,
        ),
    busMerkleRoot:
        BigInt(
            7469082661021598578966721342957393849554121759963614277226594020362804260472n,
        ),
    ferryMerkleRoot:
        BigInt(
            16585547643065588372010718035675163508420403417446192422307560350739915741648n,
        ),

    // salt
    salt: BigInt(98765n),
    saltHash:
        BigInt(
            1035379174490095295757364370441431315669465777987680425354976294595527119016n,
        ),

    // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
    magicalConstraint: BigInt(123456789n),
};

const nonZeroInputAMMExchange = {
    // external data anchoring
    extraInputsHash: BigInt(0n),

    // zAsset
    zAssetId: BigInt(0n),
    zAssetToken: BigInt(365481738974395054943628650313028055219811856521n),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(2n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(1n),
    zAssetScale: BigInt(12n),
    zAssetMerkleRoot:
        BigInt(
            3723247354377620069387735695862260139005999863996254561023715046060291769010n,
        ),
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

    chargedAmountZkp: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(100000000n),
    zAccountUtxoOutZkpAmount: BigInt(100000000n),

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
    zAccountUtxoInNullifierPrivKey:
        BigInt(
            2081961849142627796057765042284889488177156119328724687723132407819597118232n,
        ),

    zAccountUtxoInSpendKeyRandom:
        BigInt(
            185557730709061450306117592388043477299652441972445952549541952981196070710n,
        ),

    zAccountUtxoInMasterEOA:
        BigInt(407487970930055136132864974074225519407787604125n),
    zAccountUtxoInId: BigInt(33n),
    zAccountUtxoInPrpAmount: BigInt(500n),
    zAccountUtxoInZoneId: BigInt(1n),
    zAccountUtxoInExpiryTime: BigInt(1702652400n),
    zAccountUtxoInNonce: BigInt(1n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(1693306152n),
    zAccountUtxoInNetworkId: BigInt(2n),

    zAccountUtxoInCommitment:
        BigInt(
            883577885029992475849474167057954109513915827487763736646723184112542450368n,
        ),
    zNetworkId: BigInt(2n),

    // Claimed voucher(vouchers) balance
    depositAmountPrp: BigInt(0n),

    // For Voucher Exchange withdrawal of PRP is 0
    withdrawAmountPrp: BigInt(500n),
    zAccountUtxoOutPrpAmount: BigInt(0n),

    zAccountUtxoInSpendPrivKey:
        BigInt(
            1364957401031907147846036885962614753763820022581024524807608342937054566107n,
        ),

    zAccountUtxoInNullifier:
        BigInt(
            1438653281840950534109019528877092118253883422005659805831554379740541303576n,
        ),
    zAccountUtxoInMerkleTreeSelector: [BigInt(1n), BigInt(0n)],
    zAccountUtxoInPathIndices: [
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
        BigInt(0n),
    ],
    zAccountUtxoInPathElements: [
        BigInt(
            19047992597093047336371215524754541878461093335047259582748851115004307254010n,
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
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
        BigInt(0),
    ],

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

    zAccountUtxoOutSpendKeyRandom:
        BigInt(
            2330947425277212370453817539463162824729034812206690133672917694841149229695n,
        ),
    zAccountUtxoOutCommitment:
        BigInt(
            20753934111959939620197373452022491283879273374456256225221477995858226219663n,
        ),

    createTime: BigInt(1695282515n),

    utxoCommitment:
        BigInt(
            10737878881523789962798210406551165807070922751876233837797923419039556051321n,
        ),
    // Will be 0 as no ZAssetUTXO gets created during AMM voucher exchange tx
    utxoSpendPubKey: [
        BigInt(
            16242144124999549881001750798061860694310000906329588094216364089104708054049n,
        ),
        BigInt(
            10560487167730454196440910098054184596052350463925947689880260088216647168026n,
        ),
    ],
    utxoSpendKeyRandom:
        BigInt(
            486680520450277763296988191529930687770613990732419092696511815390188797858n,
        ),

    zZoneOriginZoneIDs: BigInt(1n),
    zZoneTargetZoneIDs: BigInt(1n),
    zZoneNetworkIDsBitMap: BigInt(3n),
    zZoneTrustProvidersMerkleTreeLeafIDsAndRulesList: BigInt(91n),
    zZoneKycExpiryTime: BigInt(10368000n), // 1 week epoch time
    zZoneKytExpiryTime: BigInt(86400n),
    zZoneDepositMaxAmount: BigInt(5 * 10 ** 10),
    zZoneWithrawMaxAmount: BigInt(5 * 10 ** 10),
    zZoneInternalMaxAmount: BigInt(5 * 10 ** 12),
    zZoneMerkleRoot:
        BigInt(
            2768686232753548194788154003002220124197365245281377680762459495658913308970n,
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
    zZoneEdDsaPubKey: [
        BigInt(
            1079947189093879423832572021742411110959706509214994525945407912687412115152n,
        ),
        BigInt(
            6617854811593651784376273094293148407007707755076821057553730151008062424747n,
        ),
    ],
    zZoneZAccountIDsBlackList:
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
    zZoneMaximumAmountPerTimePeriod: BigInt(5 * 10 ** 14),
    zZoneTimePeriodPerMaximumAmount: BigInt(86400n),

    zNetworkChainId: BigInt(80001n),
    zNetworkIDsBitMap: BigInt(3n),
    zNetworkTreeMerkleRoot:
        BigInt(
            14012219796450685573713237305847642356367283250649627741328974142691321346497n,
        ),
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
    zNetworkTreePathIndices: [
        BigInt(1n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],
    daoDataEscrowPubKey: [
        BigInt(
            12272087043529289524334796370800745508281317430063431496260996322077559426628n,
        ),
        BigInt(
            9194872949126287643523554866093178264045906284036198776275995684726142899669n,
        ),
    ],
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(1000n),
    forDepositReward: BigInt(0n),

    trustProvidersMerkleRoot:
        BigInt(
            17322022431886165400149810602305622216747412620247038711546582810646517935323n,
        ),
    staticTreeMerkleRoot:
        BigInt(
            15323795652282733476787593554593633163509524267163105218965028724899034265607n,
        ),
    forestMerkleRoot:
        BigInt(
            20557090278631251535517221207134967577228485466429579353724229553206573093976n,
        ),
    taxiMerkleRoot:
        BigInt(
            21078238521337523625806977154031988767929399923323679789427062985634312723305n,
        ),
    busMerkleRoot:
        BigInt(
            19737251934703046596098128694620290692612524266227769076521218008050765724331n,
        ),
    ferryMerkleRoot:
        BigInt(
            16585547643065588372010718035675163508420403417446192422307560350739915741648n,
        ),

    // salt
    salt: BigInt(98765n),
    saltHash:
        BigInt(
            1035379174490095295757364370441431315669465777987680425354976294595527119016n,
        ),

    // magical constraint - groth16 attack: https://geometry.xyz/notebook/groth16-malleability
    magicalConstraint: BigInt(123456789n),
};

// zero input
// data = zeroInput;

// non zero input voucher exchange
// data = nonZeroInputVoucherExchange;

// non zero input AMM exchange
data = nonZeroInputAMMExchange;

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
