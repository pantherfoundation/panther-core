import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const zAccount_renewal_wasm_file_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_js/main_zAccount_renewal_v1.wasm',
);

const zAccount_renewal_witness = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_js/generate_witness.js',
);

const proving_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_extended_final.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_renewal_v1_extended_verification_key.json',
);

export const generateProof = async (input: {}) => {
    await wtns.calculate(
        input,
        zAccount_renewal_wasm_file_path,
        zAccount_renewal_witness,
        null,
    );
    const prove = await groth16.prove(
        proving_key_path,
        zAccount_renewal_witness,
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

const zeroInputForZAccountRenewal = {
    extraInputsHash: BigInt(0n),
    chargedAmountZkp: BigInt(0n),

    zAssetId: BigInt(0n),
    zAssetToken: BigInt(0n),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(0n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(0n),
    zAssetScale: BigInt(0n),
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

    zAccountUtxoInRootSpendPrivKey: BigInt(0n),
    zAccountUtxoInRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountUtxoInSpendKeyRandom: BigInt(0n),

    zAccountUtxoInMasterEOA: BigInt(0n),
    zAccountUtxoInId: BigInt(0n),
    zAccountUtxoInZkpAmount: BigInt(0n),
    zAccountUtxoInPrpAmount: BigInt(0n),
    zAccountUtxoInZoneId: BigInt(0n),
    zAccountUtxoInExpiryTime: BigInt(0n),
    zAccountUtxoInNonce: BigInt(0n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(0n),
    zAccountUtxoInCreateTime: BigInt(0n),
    zAccountUtxoInNetworkId: BigInt(0n),

    zNetworkId: BigInt(0n),
    zAccountUtxoInCommitment: BigInt(0n),

    zAccountUtxoInNullifier: BigInt(0n),
    zAccountUtxoOutZkpAmount: BigInt(0n),
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

    zAccountUtxoOutSpendKeyRandom: BigInt(0n),
    zAccountUtxoOutExpiryTime: BigInt(0n),
    zAccountUtxoOutCreateTime: BigInt(0n),

    zZoneKycExpiryTime: BigInt(0n),
    zAccountUtxoOutCommitment: BigInt(0n),

    kycSignedMessagePackageType: BigInt(1n),
    kycSignedMessageTimestamp: BigInt(0n),
    kycSignedMessageSender: BigInt(0n),
    kycSignedMessageReceiver: BigInt(0n),
    kycSignedMessageSessionId: BigInt(0n),
    kycSignedMessageRuleId: BigInt(0n),

    kycKytMerkleRoot: BigInt(0n),
    kycEdDsaPubKey: [BigInt(0n), BigInt(1n)],
    kycSignature: [BigInt(0n), BigInt(0n), BigInt(0n)],
    kycSignedMessageHash: BigInt(0n),
    kycEdDsaPubKeyExpiryTime: BigInt(0n),

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
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(0n),
    kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),

    zZoneEdDsaPubKey: [BigInt(0n), BigInt(1n)],
    zZoneOriginZoneIDs: BigInt(0n),
    zZoneTargetZoneIDs: BigInt(0n),
    zZoneNetworkIDsBitMap: BigInt(0n),
    zZoneKytExpiryTime: BigInt(0n),
    zZoneDepositMaxAmount: BigInt(0n),
    zZoneWithrawMaxAmount: BigInt(0n),
    zZoneInternalMaxAmount: BigInt(0n),
    zZoneZAccountIDsBlackList:
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
    zZoneMaximumAmountPerTimePeriod: BigInt(0n),
    zZoneTimePeriodPerMaximumAmount: BigInt(0n),

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
    zNetworkChainId: BigInt(0n),
    zNetworkIDsBitMap: BigInt(0n),
    forTxReward: BigInt(0n),
    forUtxoReward: BigInt(0n),
    forDepositReward: BigInt(0n),

    daoDataEscrowPubKey: [BigInt(0n), BigInt(1n)],
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

    zZoneMerkleRoot: BigInt(0n),
    staticTreeMerkleRoot: BigInt(0n),

    forestMerkleRoot: BigInt(0n),
    taxiMerkleRoot: BigInt(0n),
    busMerkleRoot: BigInt(0n),
    ferryMerkleRoot: BigInt(0n),

    salt: BigInt(0n),
    saltHash: BigInt(0n),
    magicalConstraint: BigInt(0n),
};

const nonZeroInputForZAccountRenewal = {
    extraInputsHash: BigInt(0n),

    // [1] - Verify zAsset's membership
    // For zAccount renewal process exteral asset information is 0
    // i.e token and tokenId must be 0 as we are dealing with renewal it is obvious that we are dealing with a ZAccount which has already involved in the MASP txs,
    // which inturn means that the ZAccount has already deposited external asset to the MASP
    // Also renewal tx is all about updating the expiryTime of a ZAccount
    // Hence the external amount of token deposit or withdrawal will also be 0
    // i.e depositAmount and withdrawAmount will be 0
    zAssetId: BigInt(0n),
    zAssetToken: BigInt(0xac088b095f41ae65bec3aa4b645a0a0423388bcdn),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(1n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(1n),
    zAssetScale: BigInt(0n),
    zAssetMerkleRoot:
        BigInt(
            12291659056154266375334883320348019806271858654516961231879779711830670001842n,
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

    // [2] - Check zAsset - Done

    // [3] - Zkp balance
    // Since there will be no external/internal input/output
    // depositAmount, withdrawAmount, totalUtxoInAmount, totalUtxoOutAmount will be 0

    // 50 is the ZAccount ZKP amount which we set during the ZAccount registration process (please refer to ZAccountRegistrationNonZeroInputWitnessGeneration.test.ts integration test for more details)
    // Assuming that ZAccount has been involved in the MASP tx, hence the ZAccount ZKP amount is reduced from the initial value which we set during ZAccount Registration
    // So let's assume ZAccount has spent 20 ZKP during these tx, hence the ZKP amount left is 30
    zAccountUtxoInZkpAmount: BigInt(30n),
    // chargedAmountZkp is protocol + relayer fee in ZKP, for every tx that ZAccount does this is the minimum fee in ZKP that will get deducted from ZAccount
    chargedAmountZkp: BigInt(5n),
    zAccountUtxoOutZkpAmount: BigInt(25n),

    // [4] - Verify input 'zAccount UTXO input'
    // verify root spend key
    zAccountUtxoInRootSpendPrivKey:
        BigInt(
            1373679790059947716009348979891666704441891413152620235533738526566441607836n,
        ),
    zAccountUtxoInRootSpendPubKey: [
        BigInt(
            12145192005176226861521344364385235319411642944472049576533844974362874884912n,
        ),
        BigInt(
            3806360534113678626454222391663570333911286964678234024800930715719248331406n,
        ),
    ],
    // derive spend pub key
    zAccountUtxoInSpendKeyRandom:
        BigInt(
            2340137772334602010357676040383629302593269637370615234782832501387264356683n,
        ),

    zAccountUtxoInMasterEOA:
        BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen),
    zAccountUtxoInId: BigInt(1234n),
    zAccountUtxoInPrpAmount: BigInt(46n),
    zAccountUtxoInZoneId: BigInt(1n),
    //zAccountUtxoInExpiryTime = zAccountCreateTime + BigInt(604800n) (1 week) = 1688007610n
    zAccountUtxoInExpiryTime: BigInt(1688007610n), // Thu Jun 29 2023 03:00:10 GMT+0000
    zAccountUtxoInNonce: BigInt(8n),
    zAccountUtxoInTotalAmountPerTimePeriod: BigInt(100n),
    zAccountUtxoInCreateTime: BigInt(1687402810n), // 1687402800 (which is Thu Jun 22 2023 03:00:10 GMT+0000)
    zAccountUtxoInNetworkId: BigInt(1n),
    zAccountUtxoInCommitment:
        BigInt(
            17387488474656889694867219051565895648719695177412451492464602723819436923679n,
        ),
    zNetworkId: BigInt(1n),

    // [6] - Verify zAccountUtxoIn nullifier
    zAccountUtxoInNullifier:
        BigInt(
            2994132316786135523210311335731537829558184739966469614652581809956454367397n,
        ),

    // [7] - Verify zAccoutId exclusion proof
    // No ZAccount is blacklisted
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

    // [8] - Verify zAccount UTXO out
    zAccountUtxoOutSpendKeyRandom:
        BigInt(
            382036101399028007353605597745510288053945014934511009097667341140757509351n,
        ),
    zAccountUtxoOutExpiryTime: BigInt(1688877000n),
    zAccountUtxoOutCreateTime: BigInt(1688272200n),
    zZoneKycExpiryTime: BigInt(604800n),
    // [9] - Verify zAccountUtxoOut commitment
    zAccountUtxoOutCommitment:
        BigInt(
            4620886350083955795296478081677112977221935533454853777506793928266116362553n,
        ),
    // [10] - Verify KYT signature
    kycSignedMessagePackageType: BigInt(1),
    kycSignedMessageTimestamp: BigInt(1687489200),
    kycSignedMessageSender: BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen),
    kycSignedMessageReceiver: BigInt(0n),
    kycSignedMessageSessionId: 3906n,
    kycSignedMessageRuleId: BigInt(16n),
    kycSignedMessageHash:
        BigInt(
            4420531866412014575408224684585724661577745605424471385242083653541242299472n,
        ),
    kycSignature: [
        BigInt(
            834458324831473606631783243389498276872766277504948872488162954626615025357n,
        ),
        BigInt(
            11641340329930283083069007831002934998780161274736733641123979383052463483780n,
        ),
        BigInt(
            20930079739059236718078105952189995768043348765841153860493384092960801184861n,
        ),
    ],
    kycKytMerkleRoot:
        BigInt(
            18139283499551121798144508352920340786793810282154757122124989082341271083633n,
        ),
    kycEdDsaPubKey: [
        BigInt(
            13277427435165878497778222415993513565335242147425444199013288855685581939618n,
        ),
        BigInt(
            13622229784656158136036771217484571176836296686641868549125388198837476602820n,
        ),
    ],
    kycEdDsaPubKeyExpiryTime: BigInt(1719111600n),
    kycPathElements: [
        BigInt(
            8182442114680484104794800359347888390550258022377668063579024785808762439749n,
        ),
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
    kycPathIndices: [
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
    kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(272n),

    zZoneEdDsaPubKey: [
        BigInt(
            13844307712101580138976418881985895509771215702310325755324993649339795145459n,
        ),
        BigInt(
            2316855448348045196803672303986951089389471489704750331692824393498410052392n,
        ),
    ],
    zZoneOriginZoneIDs: BigInt(123n),
    zZoneTargetZoneIDs: BigInt(156n),
    zZoneNetworkIDsBitMap: BigInt(1234n),
    zZoneKytExpiryTime: BigInt(3600n),
    zZoneDepositMaxAmount: BigInt(200n),
    zZoneWithrawMaxAmount: BigInt(150n),
    zZoneInternalMaxAmount: BigInt(150n),
    zZoneZAccountIDsBlackList: BigInt(0n),
    zZoneMaximumAmountPerTimePeriod: BigInt(150n),
    zZoneTimePeriodPerMaximumAmount: BigInt(86400n),

    zZonePathElements: [
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
    zNetworkChainId: BigInt(1n),
    zNetworkIDsBitMap: BigInt(1n),
    forTxReward: BigInt(1n),
    forUtxoReward: BigInt(2n),
    forDepositReward: BigInt(3n),

    daoDataEscrowPubKey: [
        BigInt(
            13801722253518986324105008999395866282063706397990269215703587397313668669202n,
        ),
        BigInt(
            21263474481107240615412142108872300257673976823368253125988126712592278779858n,
        ),
    ],
    zNetworkTreeMerkleRoot:
        BigInt(
            3571799819190386765638761636798698138144469641608011835483658954125713500776n,
        ),

    zNetworkTreePathElements: [
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
    ],
    zNetworkTreePathIndices: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],

    zZoneMerkleRoot:
        BigInt(
            3853335516101579875457750934935398055005280448398251411213634628862424762402n,
        ),
    staticTreeMerkleRoot:
        BigInt(
            11728486084117138299049842970728391864873855415795077492316123666247373393728n,
        ),

    forestMerkleRoot:
        BigInt(
            16616159038183636829667398880414570825997904123457688426875723483398671385616n,
        ),
    taxiMerkleRoot: BigInt(0n),
    // Bus is the most used mode of UTXO addition, hence the ZAccount UTXO's and ZAsset UTXO's will get added to this merkle tree in this case.
    // This value can be revisited (@sushma) when we finish main tx's like deposit, withdraw, internal transfer, based on the type of txs hashes will lead to change in the value of the root.
    // For the sake of simplicity lets assume that between ZAccount registration and ZAccount renewal 8 txs have happened and 8 UTXO's (ZAccount and ZAsset will be added to the tree)
    // @sushma - Mimic this case later
    // For time being this will the root hash for all 8 txs
    busMerkleRoot: BigInt(12345678n),
    ferryMerkleRoot: BigInt(0n),

    salt: BigInt(1122n),
    saltHash:
        BigInt(
            14467678450995291425695410446001142759740457319727550794584424937448392560063n,
        ),
    magicalConstraint: BigInt(3456n),
};

// zero input
// data = zeroInputForZAccountRenewal;
data = nonZeroInputForZAccountRenewal;

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
