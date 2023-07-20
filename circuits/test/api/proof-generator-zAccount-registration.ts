import * as path from 'path';
import {wtns, groth16} from 'snarkjs';
import {getOptions} from '../helpers/circomTester';

const opts = getOptions();

const zccount_registration_wasm_file_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_registration_v1_js/main_zAccount_registration_v1.wasm',
);

const zccount_registration_witness = path.join(
    opts.basedir,
    './compiled/main_zAccount_registration_v1_js/generate_witness.js',
);

const proving_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_registration_v1_extended_final.zkey',
);

const verification_key_path = path.join(
    opts.basedir,
    './compiled/main_zAccount_registration_v1_extended_verification_key.json',
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
    zkpAmount: BigInt(0n),
    zkpChange: BigInt(0n),

    // zAsset
    zAssetId: BigInt(0n),
    zAssetToken: BigInt(0n),
    zAssetTokenId: BigInt(0n),
    zAssetNetwork: BigInt(0n),
    zAssetOffset: BigInt(0n),
    zAssetWeight: BigInt(0n),
    zAssetScale: BigInt(0n),
    zAssetMerkleRoot: BigInt(0n),
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
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
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
    zAccountRootSpendPrivKey: BigInt(0n),
    zAccountRootSpendPubKey: [BigInt(0n), BigInt(1n)],
    zAccountMasterEOA: BigInt(0n),
    zAccountSpendKeyRandom: BigInt(0n),
    zAccountCommitment: BigInt(0n),
    zAccountNullifier: BigInt(0n),

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
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(0n),
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
    zZoneEdDsaPubKey: [BigInt(0n), BigInt(0n)],
    zZoneZAccountIDsBlackList: BigInt(
        '1766847064778384329583297500742918515827483896875618958121606201292619775',
    ),
    zZoneMaximumAmountPerTimePeriod: BigInt(0n),
    zZoneTimePeriodPerMaximumAmount: BigInt(0n),

    // KYC
    kycEdDsaPubKey: [BigInt(0n), BigInt(0n)],
    kycEdDsaPubKeyExpiryTime: BigInt(0n),
    kycKytMerkleRoot: BigInt(0n),
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
    kycPathIndex: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
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
    zNetworkTreePathIndex: [
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
    extraInputsHash: BigInt(0n),

    // zkp amounts (not scaled)
    zkpAmount: BigInt(50n),
    zkpChange: BigInt(0n),

    // ZAsset membership verification
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

    // zAccount UTXO input verification
    zAccountRootSpendPrivKey:
        BigInt(
            1373679790059947716009348979891666704441891413152620235533738526566441607836n,
        ),
    zAccountRootSpendPubKey: [
        BigInt(
            12145192005176226861521344364385235319411642944472049576533844974362874884912n,
        ),
        BigInt(
            3806360534113678626454222391663570333911286964678234024800930715719248331406n,
        ),
    ],
    zAccountSpendKeyRandom:
        BigInt(
            2340137772334602010357676040383629302593269637370615234782832501387264356683n,
        ),

    zAccountMasterEOA: BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen),
    zAccountId: BigInt(1234n),
    zAccountZkpAmount: BigInt(50n),
    zAccountPrpAmount: BigInt(40n),
    zAccountZoneId: BigInt(1n),
    zAccountExpiryTime: BigInt(1688007610n),
    zAccountNonce: BigInt(0n),
    zAccountTotalAmountPerTimePeriod: BigInt(0n), // This field will be 0 at the time of registration
    zAccountCreateTime: BigInt(1687402810n),
    zAccountNetworkId: BigInt(1n),

    zNetworkId: BigInt(1n),

    // ZAccountUtxo commitment verification
    zAccountCommitment:
        BigInt(
            13683953030945782116588387268262807344430183373976224469652321118488063371846n,
        ),

    // ZAccount nullifier verification
    zAccountNullifier:
        BigInt(
            2994132316786135523210311335731537829558184739966469614652581809956454367397n,
        ),

    // verify if current zAccountId is blacklisted or not!
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

    // KYC signature verification
    kycSignedMessagePackageType: BigInt(1),
    kycSignedMessageTimestamp: BigInt(1687489200),
    kycSignedMessageSender: BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen),
    kycSignedMessageReceiver: BigInt(0),
    kycSignedMessageSessionId: 3906n,
    kycSignedMessageRuleId: BigInt(16n), // RuleId's value can't be more than 2^8-1=255
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

    // KYCEdDSA public key membership verification
    kycEdDsaPubKey: [
        BigInt(
            13277427435165878497778222415993513565335242147425444199013288855685581939618n,
        ),
        BigInt(
            13622229784656158136036771217484571176836296686641868549125388198837476602820n,
        ),
    ],
    kycEdDsaPubKeyExpiryTime: BigInt(1719111600n),
    kycKytMerkleRoot:
        BigInt(
            18139283499551121798144508352920340786793810282154757122124989082341271083633n,
        ),
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
    kycPathIndex: [
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

    // kyc leaf-id(1) & rule(16) is allowed in zZone
    kycMerkleTreeLeafIDsAndRulesOffset: BigInt(0n),

    // zZone
    zZoneOriginZoneIDs: BigInt(123n),
    zZoneTargetZoneIDs: BigInt(156n),
    zZoneNetworkIDsBitMap: BigInt(1234n),
    zZoneKycKytMerkleTreeLeafIDsAndRulesList: BigInt(272n),
    zZoneKycExpiryTime: BigInt(604800n), // 1 week epoch time
    zZoneKytExpiryTime: BigInt(3600n),
    zZoneDepositMaxAmount: BigInt(200n),
    zZoneWithrawMaxAmount: BigInt(150n),
    zZoneInternalMaxAmount: BigInt(150n),
    zZoneMerkleRoot:
        BigInt(
            3853335516101579875457750934935398055005280448398251411213634628862424762402n,
        ),
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
            13844307712101580138976418881985895509771215702310325755324993649339795145459n,
        ),
        BigInt(
            2316855448348045196803672303986951089389471489704750331692824393498410052392n,
        ),
    ],
    zZoneZAccountIDsBlackList: BigInt(0n), // no zAccountID is in blockclist
    zZoneMaximumAmountPerTimePeriod: BigInt(150n),
    zZoneTimePeriodPerMaximumAmount: BigInt(86400n),

    // zNetworks tree
    // network parameters:
    // 1) is-active - 1 bit (circuit will set it to TRUE ALWAYS)
    // 2) network-id - 6 bit
    // 3) rewards params - all of them: forTxReward, forUtxoReward, forDepositReward
    // 4) daoDataEscrowPubKey[2]
    zNetworkChainId: BigInt(1n),
    zNetworkIDsBitMap: BigInt(1n),
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
    zNetworkTreePathIndex: [
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
        BigInt(0n),
    ],
    daoDataEscrowPubKey: [
        BigInt(
            13801722253518986324105008999395866282063706397990269215703587397313668669202n,
        ),
        BigInt(
            21263474481107240615412142108872300257673976823368253125988126712592278779858n,
        ),
    ],
    forTxReward: BigInt(1n),
    forUtxoReward: BigInt(2n),
    forDepositReward: BigInt(3n),

    // static tree merkle root
    // Poseidon of:
    // 1) zAssetMerkleRoot
    // 2) zAccountBlackListMerkleRoot
    // 3) zNetworkTreeMerkleRoot
    // 4) zZoneMerkleRoot
    // 5) kycKytMerkleRoot
    staticTreeMerkleRoot:
        BigInt(
            11728486084117138299049842970728391864873855415795077492316123666247373393728n,
        ),

    // forest root
    // Poseidon of:
    // 1) UTXO-Taxi-Tree   - 6 levels MT
    // 2) UTXO-Bus-Tree    - 26 levels MT
    // 3) UTXO-Ferry-Tree  - 6 + 26 = 32 levels MT (6 for 16 networks)
    // 4) Static-Tree
    forestMerkleRoot:
        BigInt(
            11038309636808859781829595886770882067715836362130672314164878094832132730791n,
        ),
    taxiMerkleRoot:
        BigInt(
            20775607673010627194014556968476266066927294572720319469184847051418138353016n,
        ),
    busMerkleRoot:
        BigInt(
            8163447297445169709687354538480474434591144168767135863541048304198280615192n,
        ),
    ferryMerkleRoot:
        BigInt(
            21443572485391568159800782191812935835534334817699172242223315142338162256601n,
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
// main();
