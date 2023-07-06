import * as path from 'path';

import circom_wasm_tester from 'circom_tester';
const wasm_tester = circom_wasm_tester.wasm;

import {getOptions} from './helpers/circomTester';
import {wtns} from 'snarkjs';
import poseidon from 'circomlibjs/src/poseidon';
import {
    generateRandom256Bits,
    moduloBabyJubSubFieldPrime,
} from '@panther-core/crypto/lib/base/field-operations';

import {deriveChildPubKeyFromRootPubKey} from '@panther-core/crypto/lib/base/keypairs';

describe('ZAccount Renewal - Non Zero Input - Witness computation', async function (this: any) {
    let circuit: any;
    let mainZAccountRenewalWasm: any;
    let mainZAccountRenewalWitness: any;

    this.timeout(10000000);

    before(async () => {
        const opts = getOptions();
        const input = path.join(
            opts.basedir,
            './circuits/main_zAccount_renewal_v1.circom',
        );
        circuit = await wasm_tester(input, opts);

        mainZAccountRenewalWasm = path.join(
            opts.basedir,
            './compiled/main_zAccount_renewal_v1_js/main_zAccount_renewal_v1.wasm',
        );

        mainZAccountRenewalWitness = path.join(
            opts.basedir,
            './compiled/main_zAccount_renewal_v1_js/generate_witness.js',
        );

        // zAccountUtxoInNoteHasher computation

        const spendPubKey = [
            BigInt(
                17038548925136330597901776143419600886904054884722333959338076954470037655999n,
            ),
            BigInt(
                15181232296682046932319227486729475921640708467464477865639020738569527794871n,
            ),
        ];
        const zAccountRootSpendPubKey = [
            BigInt(
                12145192005176226861521344364385235319411642944472049576533844974362874884912n,
            ),
            BigInt(
                3806360534113678626454222391663570333911286964678234024800930715719248331406n,
            ),
        ];
        const zAccountMasterEOA =
            BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen);
        const zAccountId = BigInt(1234n);

        // 50 is the ZAccount ZKP amount which we set during the ZAccount registration process (please refer to ZAccountRegistrationNonZeroInputWitnessGeneration.test.ts integration test for more details)
        // Assuming that ZAccount has been involved in the MASP tx, hence the ZAccount ZKP amount is reduced from the initial value which we set during ZAccount Registration
        // So let's assume ZAccount has spent 20 ZKP during these tx, hence the ZKP amount left is 30
        const zAccountZkpAmount = BigInt(30n);

        // Same is the case with ZAccount PRP amount
        // Assuming that ZAccount has been involved in the MASP tx, the Panther Rewards that it got for depositing asset to MASP will increase
        // So let's assume ZAccount has gained 6 PRP (during the ZAccount registration process it was 40, now 40+6=46), so PRP will be 46

        const zAccountPrpAmount = BigInt(46n);
        const zAccountZoneId = BigInt(1n); // zoneId

        // zAccountNonce - As the number of outgoing transaction increases nonce increases by 1.
        // So let's assume that the ZAccount has done 8 txs from the time of ZAccount registration to ZAccount renewal (now)
        // So zAccountNonce becomes 8
        const zAccountNonce = BigInt(8n);

        // During the ZAccount registration process this will be 0, as the ZAccount performs the transactions (deposit/withdraw/internal transfers) this field will get updated.
        // This value is specific to zZone (Zone on which this ZAccount is registered)
        // For more zone specific details refer to 'main transaction non zero deposit'
        // For zZone '1' the maximum amount a ZAccount can transact (asssuming this ZAccount is in zZone 1) is 150 / day (86400 seconds)
        // So lets assumse that the total amount of transfer that the ZAccount has done for all the tx is 100 (which is less than the maximum amount per zZone (150))
        const zAccountTotalAmountPerTimePeriod = BigInt(100n);
        // Create time of a ZAccount is in accordance with the current block timestamp.
        // Ex: If current block timestamp is - 1687402800 (which is Thu Jun 22 2023 03:00:00 GMT+0000)
        // and ZAccount will be current block timestamp + delta in zAccount creation (eg:10 seconds)
        // zAccountCreateTime - 1687402810
        const zAccountCreateTime = BigInt(1687402810n); //createTime

        // Expiry time of a ZAccount UTXO is defined by the creation time of the UTXO + the KYC expiry time for a particular zone
        // Ex: If zone1 has a predefined zone expiry as 1 week (i.e 604800 epoch seconds) then the expiry time of a ZAccount UTXO would be the creation time + predefined zone expiry as 1 week (i.e 604800 epoch seconds)
        // This way each zAccount UTXO created has an expiry specific to zZones.

        // Expiry time of a ZAccount UTXO is zAcoount created time + the zone specific kyc expiry time
        const zAccountExpiryTime = zAccountCreateTime + BigInt(604800n);
        // console.log("zAccountExpiryTime=>",zAccountExpiryTime); // 1688007610n

        const zAccountNetworkId = BigInt(1n);

        const zAccountNoteHasher = poseidon([
            spendPubKey[0],
            spendPubKey[1],
            zAccountRootSpendPubKey[0],
            zAccountRootSpendPubKey[1],
            zAccountMasterEOA,
            zAccountId,
            zAccountZkpAmount,
            zAccountPrpAmount,
            zAccountZoneId,
            zAccountExpiryTime,
            zAccountNonce,
            zAccountTotalAmountPerTimePeriod,
            zAccountCreateTime,
            zAccountNetworkId,
        ]);
        // 17387488474656889694867219051565895648719695177412451492464602723819436923679n
        // console.log('zAccountNoteHasher=>', zAccountNoteHasher);

        // zAccountUtxoInNullifierHasher
        let zAccountUtxoInId = BigInt(1234n);
        let zAccountUtxoInZoneId = BigInt(1n);
        let zAccountUtxoInNetworkId = BigInt(1n);
        let zAccountUtxoInRootSpendPrivKey =
            BigInt(
                1373679790059947716009348979891666704441891413152620235533738526566441607836n,
            );
        let zAccountUtxoInNullifierHasher = poseidon([
            zAccountUtxoInId,
            zAccountUtxoInZoneId,
            zAccountUtxoInNetworkId,
            zAccountUtxoInRootSpendPrivKey,
        ]);
        // 2994132316786135523210311335731537829558184739966469614652581809956454367397n
        // console.log(
        //     'zAccountUtxoInNullifierHasher=>',
        //     zAccountUtxoInNullifierHasher,
        // );

        // [8] - Verify zAccount UTXO out
        // During ZAccount renewal ZAccount(sender) will generate a new random for the derivation of new child public keys
        // From the renewal process onwards child keys derived from ZAccount root keys will be different.

        const zAccountUtxoInRootSpendPubKey = [
            BigInt(
                12145192005176226861521344364385235319411642944472049576533844974362874884912n,
            ),
            BigInt(
                3806360534113678626454222391663570333911286964678234024800930715719248331406n,
            ),
        ];
        // New random generation by sender ZAccount
        // const senderZAccountRandom = moduloBabyJubSubFieldPrime(
        //     generateRandom256Bits(),
        // );
        // 382036101399028007353605597745510288053945014934511009097667341140757509351n
        // console.log('senderZAccountRandom=>', senderZAccountRandom);
        const senderZAccountRandom =
            382036101399028007353605597745510288053945014934511009097667341140757509351n;

        const renewalDerivedPublicKeys = deriveChildPubKeyFromRootPubKey(
            zAccountUtxoInRootSpendPubKey,
            senderZAccountRandom,
        );
        // console.log('renewalDerivedPublicKeys=>', renewalDerivedPublicKeys);
        // renewalDerivedPublicKeys - output
        // [
        //     647863126472189847174084730860335943466468447462604719306941093035347293648n,
        //     2129625120408121168591230582160150966886713941444451473751362889953257356869n
        // ]

        const zAccountUtxoInMasterEOA =
            BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fen);
        const zAccountUtxoInZkpAmount = BigInt(30n);
        const zAccountUtxoInPrpAmount = BigInt(46n);
        // During the ZAccount registration process these are the timestamps
        // zZoneKycExpiryTime for zone 1 is BigInt(604800n) i.e 1 week - 604800 seconds
        // zAccountCreateTime = BigInt(1687402810n); // (which is Thu Jun 22 2023 03:00:10 GMT+0000)
        // Therefore zAccountExpiryTime = zAccountCreateTime + BigInt(604800n); // 1688007610n - (Thu Jun 29 2023 03:00:10 GMT+0000)
        // 1688007610 (Thu Jun 29 2023 03:00:10 GMT+0000) - This is the expiry time of the ZAccount
        // Hence ZAccount will ideally go for ZAccount renewal after this time (in real time it will be now)
        // zAccountUtxoOutCreateTime > 1688007610
        // So lets assume ZAccount will opt for renewal by the - Sun Jul 02 2023 04:30:00 GMT+0000 - 1688272200
        // 1688272200(zAccountUtxoOutCreateTime) > 1688007610
        // zAccountUtxoOutExpiryTime (Sun Jul 09 2023 04:30:00 GMT+0000-1688877000) = zAccountUtxoOutCreateTime(1688272200) + zZoneKycExpiryTime(604800n)
        const zAccountUtxoOutCreateTime = BigInt(1688272200n);
        const zAccountUtxoOutExpiryTime = BigInt(1688877000n);

        const zAccountUtxoInNonce = BigInt(8n);
        const zAccountUtxoInTotalAmountPerTimePeriod = BigInt(100n);
        const zAccountUtxoOutNoteHasher = poseidon([
            renewalDerivedPublicKeys[0],
            renewalDerivedPublicKeys[1],
            zAccountUtxoInRootSpendPubKey[0],
            zAccountUtxoInRootSpendPubKey[1],
            zAccountUtxoInMasterEOA,
            zAccountUtxoInId,
            zAccountUtxoInZkpAmount,
            zAccountUtxoInPrpAmount,
            zAccountUtxoInZoneId,
            zAccountUtxoOutExpiryTime,
            zAccountUtxoInNonce + 1n,
            zAccountUtxoInTotalAmountPerTimePeriod,
            zAccountUtxoOutCreateTime,
            zAccountUtxoInNetworkId,
        ]);
        // console.log('zAccountUtxoOutNoteHasher=>', zAccountUtxoOutNoteHasher);

        const forestTreeMerkleRoot = poseidon([
            0n,
            12345678n,
            0,
            BigInt(
                98794241926285775436068491648105652937344408613430517862424107871889567640n,
            ),
        ]);
        //15106658684049704879587448454732602388027655797186180507188399839143525977492n
        // console.log('forestTreeMerkleRoot=>', forestTreeMerkleRoot);

        const saltHash = poseidon([BigInt(1122n)]);
        // 14467678450995291425695410446001142759740457319727550794584424937448392560063n
        // console.log('saltHash=>', saltHash);
    });

    const nonZeroInput = {
        extraInputsHash: BigInt(0n),

        // [1] - Verify zAsset's membership
        // For zAccount renewal process exteral asset information is 0
        // i.e token and tokenId must be 0 as we are dealing with renewal it is obvious that we are dealing with a ZAccount which has already involved in the MASP txs,
        // which inturn means that the ZAccount has already deposited external asset to the MASP
        // Also renewal tx is all about updating the expiryTime of a ZAccount
        // Hence the external amount of token deposit or withdrawal will also be 0
        // i.e depositAmount and withdrawAmount will be 0
        zAssetId: BigInt(1234n),
        zAssetToken: BigInt(0xac088b095f41ae65bec3aa4b645a0a0423388bcdn),
        zAssetTokenId: BigInt(0n),
        zAssetNetwork: BigInt(1n),
        zAssetOffset: BigInt(0n),
        zAssetWeight: BigInt(1n),
        zAssetScale: BigInt(0n),
        zAssetMerkleRoot:
            BigInt(
                6275962907379345415649569389522703371869031196602512820932047330313078509018n,
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
        kycSignedMessagePackageType: BigInt(2),
        kycSignedMessageTimestamp: BigInt(1687489200),
        kycSignedMessageSender:
            BigInt(0xecb1bf390d9fc6fe4a2589a1110c3f9dd1d535fe),
        kycSignedMessageReceiver: BigInt(0n),
        kycSignedMessageToken: BigInt(0n),
        kycSignedMessageSessionIdHex: 3906n,
        kycSignedMessageRuleId: BigInt(16n),
        kycSignedMessageAmount: BigInt(0n),
        kycSignedMessageHash:
            BigInt(
                10717882738015002841097349087135986012013943878032464141329829285655741611111n,
            ),
        kycSignature: [
            BigInt(
                2554252008483743278352014895807620295067532516855724717085618974440503828542n,
            ),
            BigInt(
                19322298997224831486690545532024867711768868330349006266991717547867183458940n,
            ),
            BigInt(
                5979978139633913435510662889209990844643859076222734966878056147242401070108n,
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
        zNetworkChainId: BigInt(1n),
        zNetworkIDsBitMap: BigInt(1234n),
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
                11533271907829962178538751916725087229735862536220341910589678396909232316213n,
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

        zZoneMerkleRoot:
            BigInt(
                3853335516101579875457750934935398055005280448398251411213634628862424762402n,
            ),
        staticTreeMerkleRoot:
            BigInt(
                98794241926285775436068491648105652937344408613430517862424107871889567640n,
            ),

        forestMerkleRoot:
            BigInt(
                15106658684049704879587448454732602388027655797186180507188399839143525977492n,
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

    it('should compute valid witness for zero input tx', async () => {
        await wtns.calculate(
            nonZeroInput,
            mainZAccountRenewalWasm,
            mainZAccountRenewalWitness,
            null,
        );
        console.log('Witness calculation successful!');
    });
});
