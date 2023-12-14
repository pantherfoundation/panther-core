import {poseidon} from 'circomlibjs';
import {MerkleTree} from '@zk-kit/merkle-tree';
import assert from 'assert';

const poseidon2or3 = (inputs: bigint[]): bigint => {
    assert(inputs.length === 3 || inputs.length === 2);
    return poseidon(inputs);
};

let zAssetMerkleTree: MerkleTree;
let zAssetMerkleTreeLeaf: bigint;

let zAccountBlackListMerkleTree: MerkleTree;
let zAccountBlackListMerkleTreeLeaf: number; // index

let zNetworkMerkleTree: MerkleTree;
let zNetworkMerkleTreeLeaf: bigint;

let zZoneRecordMerkleTree: MerkleTree;
let zZoneRecordMerkleTreeLeaf: bigint;

let trustProviderMerkleTree: MerkleTree;
let trustProviderMerkleTreeLeaf: bigint;

const initializeAllStaticTrees = async () => {
    // keccak256("Pantherprotocol")%FIELD_SIZE
    const DEFAULT_LEAF_VALUE =
        BigInt(
            2896678800030780677881716886212119387589061708732637213728415628433288554509n,
        );

    const TREE_DEPTH = 16;
    const ZNETWORK_TREE_DEPTH = 6;

    // ZAsset Merkle Tree
    // Depth - 16
    // Initial value - keccak256("Pantherprotocol")%FIELD_SIZE
    //               - 2896678800030780677881716886212119387589061708732637213728415628433288554509n
    zAssetMerkleTree = new MerkleTree(
        poseidon2or3,
        TREE_DEPTH,
        DEFAULT_LEAF_VALUE,
    );

    // ZAccount BlackList Merkle Tree
    // Depth - 16
    // Initial value - 0
    zAccountBlackListMerkleTree = new MerkleTree(
        poseidon2or3,
        TREE_DEPTH,
        BigInt(0),
    );

    // ZNetwork Merkle Tree
    // Depth - 6
    // Initial value - keccak256("Pantherprotocol")%FIELD_SIZE
    //               - 2896678800030780677881716886212119387589061708732637213728415628433288554509n
    zNetworkMerkleTree = new MerkleTree(
        poseidon2or3,
        ZNETWORK_TREE_DEPTH,
        DEFAULT_LEAF_VALUE,
    );

    // ZZone Merkle Tree
    // Depth - 16
    // Initial value - keccak256("Pantherprotocol")%FIELD_SIZE
    //               - 2896678800030780677881716886212119387589061708732637213728415628433288554509n
    zZoneRecordMerkleTree = new MerkleTree(
        poseidon2or3,
        TREE_DEPTH,
        DEFAULT_LEAF_VALUE,
    );

    // Trust Provider Merkle Tree
    // Depth - 16
    // Initial value - keccak256("Pantherprotocol")%FIELD_SIZE
    //               - 2896678800030780677881716886212119387589061708732637213728415628433288554509n
    trustProviderMerkleTree = new MerkleTree(
        poseidon2or3,
        TREE_DEPTH,
        DEFAULT_LEAF_VALUE,
    );

    console.log('All static merkle trees are initialised');
};

// ========== ZAsset Merkle Tree Operations ==========
// ========== Adding leaf to ZAsset Merkle Tree ==========
const addLeafToZAssetMerkleTree = async (
    zAsset: BigInt,
    token: BigInt,
    tokenId: BigInt,
    network: BigInt,
    offset: BigInt,
    weight: BigInt,
    scale: BigInt,
) => {
    // ZAsset Merkle tree leaf computation
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
    // console.log('zAssetMerkleTreeLeaf=>', zAssetMerkleTreeLeaf);

    zAssetMerkleTree.insert(zAssetMerkleTreeLeaf);
    console.log(`${zAssetMerkleTreeLeaf} got inserted into zAssetMerkleTree`);
};

// ========== Proof of a leaf in ZAsset Merkle Tree ==========
const getPOEOfLeafInZAssetMerkleTree = async (leafIndex: number) => {
    const poeOfzAssetLeaf = zAssetMerkleTree.createProof(leafIndex);
    // console.log('poeOfzAssetLeaf=>', poeOfzAssetLeaf);
    return poeOfzAssetLeaf;
};
// ========== ZAsset Merkle Tree Operations ==========

// ========== ZAccount BlackList Merkle Tree Operations ==========
// ========== Adding leaf to ZAccount BlackList Merkle Tree ==========
const addLeafToZAccountBlackListMerkleTree = async (leafIndex: number) => {
    zAccountBlackListMerkleTree.insert(leafIndex);
    console.log(`${leafIndex} got inserted into zAccountBlackListMerkleTree`);
};

// ========== Proof of a leaf in ZAccount BlackList Merkle Tree ==========
const getPOEOfLeafInZAccountBlackListMerkleTree = async (leafIndex: number) => {
    const poeOfzAccountBlackListMerkleTreeLeaf =
        zAccountBlackListMerkleTree.createProof(leafIndex);
    // console.log(
    //     'poeOfzAccountBlackListMerkleTreeLeaf=>',
    //     poeOfzAccountBlackListMerkleTreeLeaf,
    // );
    return poeOfzAccountBlackListMerkleTreeLeaf;
};
// ========== ZAccount BlackList Merkle Tree Operations ==========

// ========== ZNetwork Merkle Tree Operations ==========
// ========== Adding leaf to ZNetwork Merkle Tree ==========
const addLeafTozNetworkMerkleTree = async (
    active: Number,
    chainId: BigInt,
    networkId: Number,
    networkIDsBitMap: BigInt,
    forTxReward: BigInt,
    forUtxoReward: BigInt,
    forDepositReward: BigInt,
    daoDataEscrowPubKey0: BigInt,
    daoDataEscrowPubKey1: BigInt,
) => {
    // ZNetwork Merkle tree leaf computation
    const zNetworkLeafHash = poseidon([
        active,
        chainId,
        networkId,
        networkIDsBitMap,
        forTxReward,
        forUtxoReward,
        forDepositReward,
        daoDataEscrowPubKey0,
        daoDataEscrowPubKey1,
    ]);

    zNetworkMerkleTreeLeaf = zNetworkLeafHash;
    // console.log('zNetworkMerkleTreeLeaf=>', zNetworkMerkleTreeLeaf);

    zNetworkMerkleTree.insert(zNetworkMerkleTreeLeaf);
    console.log(
        `${zNetworkMerkleTreeLeaf} got inserted into zNetworkMerkleTree`,
    );
};

// ========== Proof of a leaf in ZNetwork Merkle Tree ==========
const getPOEOfLeafInzNetworkMerkleTree = async (leafIndex: number) => {
    const poeOfZNetworkMerkleTreeLeaf =
        zNetworkMerkleTree.createProof(leafIndex);
    // console.log('poeOfZNetworkMerkleTreeLeaf=>', poeOfZNetworkMerkleTreeLeaf);
    return poeOfZNetworkMerkleTreeLeaf;
};
// ========== ZNetwork Merkle Tree Operations ==========

// ========== ZZone Merkle Tree Operations ==========
// ========== Adding leaf to ZZone Merkle Tree ==========
const addLeafToZZoneRecordMerkleTree = async (
    zoneId: BigInt,
    edDsaPubKey0: BigInt,
    edDsaPubKey1: BigInt,
    originZoneIDs: BigInt,
    targetZoneIDs: BigInt,
    networkIDsBitMap: BigInt,
    trustProvidersMerkleTreeLeafIDsAndRulesList: BigInt,
    kycExpiryTime: BigInt,
    kytExpiryTime: BigInt,
    depositMaxAmount: BigInt,
    withdrawMaxAmount: BigInt,
    internalMaxAmount: BigInt,
    zAccountIDsBlackList: BigInt,
    maximumAmountPerTimePeriod: BigInt,
    timePeriodPerMaximumAmount: BigInt,
) => {
    // ZZone Merkle tree leaf computation
    const zZoneLeafHash = poseidon([
        zoneId,
        edDsaPubKey0,
        edDsaPubKey1,
        originZoneIDs,
        targetZoneIDs,
        networkIDsBitMap,
        trustProvidersMerkleTreeLeafIDsAndRulesList,
        kycExpiryTime,
        kytExpiryTime,
        depositMaxAmount,
        withdrawMaxAmount,
        internalMaxAmount,
        zAccountIDsBlackList,
        maximumAmountPerTimePeriod,
        timePeriodPerMaximumAmount,
    ]);

    zZoneRecordMerkleTreeLeaf = zZoneLeafHash;
    // console.log('zZoneRecordMerkleTreeLeaf=>', zZoneRecordMerkleTreeLeaf);

    zZoneRecordMerkleTree.insert(zZoneRecordMerkleTreeLeaf);
    console.log(
        `${zZoneRecordMerkleTreeLeaf} got inserted into zZoneRecordMerkleTree`,
    );
};

// ========== Proof of a leaf in ZZone Merkle Tree ==========
const getPOEOfLeafInZZoneMerkleTree = async (leafIndex: number) => {
    const poeOfZNetworkMerkleTreeLeaf =
        zZoneRecordMerkleTree.createProof(leafIndex);
    // console.log('poeOfZNetworkMerkleTreeLeaf=>', poeOfZNetworkMerkleTreeLeaf);
    return poeOfZNetworkMerkleTreeLeaf;
};
// ========== ZZone Merkle Tree Operations ==========

// ========== Trust Provider Merkle Tree Operations ==========
// ========== Adding leaf to Trust Provider Merkle Tree ==========
const addLeafToTrustProviderMerkleTree = async (
    key0: BigInt,
    key1: BigInt,
    expiryTime: BigInt,
) => {
    // Trust Provider Merkle tree leaf computation
    const kycKytLeafHash = poseidon([key0, key1, expiryTime]);

    trustProviderMerkleTreeLeaf = kycKytLeafHash;
    // console.log('trustProviderMerkleTreeLeaf=>', trustProviderMerkleTreeLeaf);

    trustProviderMerkleTree.insert(trustProviderMerkleTreeLeaf);
    console.log(
        `${trustProviderMerkleTreeLeaf} got inserted into kycKytMerkleTree`,
    );
};

// ========== Proof of a leaf in Trust Provider Merkle Tree ==========
const getPOEOfLeafInTrustProviderMerkleTree = async (leafIndex: number) => {
    const poeOfTrustProviderMerkleTreeLeaf =
        trustProviderMerkleTree.createProof(leafIndex);
    // console.log('poeOfTrustProviderMerkleTreeLeaf=>', poeOfTrustProviderMerkleTreeLeaf);
    return poeOfTrustProviderMerkleTreeLeaf;
};
// ========== Trust Provider Merkle Tree Operations ==========

const computeStaticMerkleRoot = async (
    zAssetMerkleRoot: BigInt,
    zAccountBlackListMerkleRoot: BigInt,
    zNetworkTreeMerkleRoot: BigInt,
    zZoneMerkleRoot: BigInt,
    trustProvidersMerkleRoot: BigInt,
) => {
    const staticMerkleRoot = poseidon([
        zAssetMerkleRoot,
        zAccountBlackListMerkleRoot,
        zNetworkTreeMerkleRoot,
        zZoneMerkleRoot,
        trustProvidersMerkleRoot,
    ]);
    console.log(`Final static merkle root is ${staticMerkleRoot}`);
};

async function main() {
    // Initialise all the static merkle trees
    await initializeAllStaticTrees();

    // ========= START - Trust Provider Merkle Tree =========
    console.log(
        '================== START - Trust Provider Merkle Tree ==================',
    );
    // Adding First leaf - PureFi attestation
    const trustProviderCommitment0 = await addLeafToTrustProviderMerkleTree(
        BigInt(
            9487832625653172027749782479736182284968410276712116765581383594391603612850n,
        ),
        BigInt(
            20341243520484112812812126668555427080517815150392255522033438580038266039458n,
        ),
        BigInt(1735689600n),
    );
    console.log(
        `Computed commitment for leaf 0 is ${trustProviderCommitment0}`,
    );

    // get the proof for leaf at position 0
    const trustProviderMerkleProofAfterLeaf0 =
        await getPOEOfLeafInTrustProviderMerkleTree(0);
    console.log(
        `State of Trust Provider Merkle Tree after the insertion of 0 leaf`,
        trustProviderMerkleProofAfterLeaf0,
    );

    // Adding Second leaf - Safe Operator's public key (for encryption)
    const trustProviderCommitment1 = await addLeafToTrustProviderMerkleTree(
        BigInt(
            6461944716578528228684977568060282675957977975225218900939908264185798821478n,
        ),
        BigInt(
            6315516704806822012759516718356378665240592543978605015143731597167737293922n,
        ),
        BigInt(1735689600n),
    );
    console.log(
        `Computed commitment for leaf 1 is ${trustProviderCommitment1}`,
    );

    // get the proof for leaf at position 1
    const trustProviderMerkleProofAfterLeaf1 =
        await getPOEOfLeafInTrustProviderMerkleTree(1);
    console.log(
        `State of Trust Provider Merkle Tree after the insertion of 1 leaf`,
        trustProviderMerkleProofAfterLeaf1,
    );
    console.log(
        'END - ================== Trust Provider Merkle Tree ================== \n',
    );
    // ========= END - Trust Provider Merkle Tree =========

    // ========= START - ZAsset Merkle Tree =========
    console.log(
        'START - ================== ZAsset Merkle Tree ==================',
    );
    // Adding First leaf to ZAssetMerkleTree at position 0 - testZKP token on Mumbai
    const zAssetCommitment0 = await addLeafToZAssetMerkleTree(
        0n,
        362235805296134286480704068378271723420643984799n,
        0n,
        2n,
        0n,
        20n,
        BigInt(10 ** 12), // 1 ZKP = 1 * 10^18 unscaled units / 1 * 10^6 scaled units
    );
    console.log(`Computed commitment for leaf 0 is ${zAssetCommitment0}`);

    // get the proof for leaf at position 0
    const ZAssetMerkleProofAfterLeaf0 = await getPOEOfLeafInZAssetMerkleTree(0);
    console.log(
        `State of ZAsset Merkle Tree after the insertion of 0 leaf`,
        ZAssetMerkleProofAfterLeaf0,
    );

    // Adding First leaf to ZAssetMerkleTree at position 1 - Matic token on Mumbai
    const zAssetCommitment1 = await addLeafToZAssetMerkleTree(
        2n,
        0n,
        0n,
        2n,
        0n,
        700n,
        BigInt(10 ** 12),
    );
    console.log(`Computed commitment for leaf 1 is ${zAssetCommitment1}`);

    // get the proof for leaf at position 0
    const ZAssetMerkleProofAfterLeaf1 = await getPOEOfLeafInZAssetMerkleTree(1);
    console.log(
        `State of ZAsset Merkle Tree after the insertion of 1 leaf`,
        ZAssetMerkleProofAfterLeaf1,
    );
    console.log(
        'END - ================== ZAsset Merkle Tree ================== \n',
    );
    // ========= END - ZAsset Merkle Tree =========

    // ========= START - ZNetwork Merkle Tree =========
    console.log(
        'START - ================== ZNetwork Merkle Tree ==================',
    );
    // Adding First leaf to zNetworkMerkleTree at position 0 - Goerli
    const zNetworkCommitment0 = await addLeafTozNetworkMerkleTree(
        1,
        5n,
        1,
        3n,
        10n,
        1828n,
        57646075n,
        BigInt(
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        ),
        BigInt(
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ),
    );

    console.log(`Computed commitment for leaf 0 is ${zNetworkCommitment0}`);

    // get the proof for leaf at position 0
    const ZNetworkMerkleProofAfterLeaf0 =
        await getPOEOfLeafInzNetworkMerkleTree(0);
    console.log(
        `State of ZNetwork Merkle Tree after the insertion of 0 leaf`,
        ZNetworkMerkleProofAfterLeaf0,
    );

    // Adding Second leaf to zNetworkMerkleTree at position 1 - Polygon Mumbai
    const zNetworkCommitment1 = await addLeafTozNetworkMerkleTree(
        1,
        80001n,
        2,
        3n,
        10n,
        1828n,
        57646075n,
        BigInt(
            6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        ),
        BigInt(
            12531080428555376703723008094946927789381711849570844145043392510154357220479n,
        ),
    );

    console.log(`Computed commitment for leaf 1 is ${zNetworkCommitment1}`);

    // get the proof for leaf at position 1
    const ZNetworkMerkleProofAfterLeaf1 =
        await getPOEOfLeafInzNetworkMerkleTree(1);
    console.log(
        `State of ZNetwork Merkle Tree after the insertion of 1 leaf`,
        ZNetworkMerkleProofAfterLeaf1,
    );

    console.log(
        'END - ================== ZNetwork Merkle Tree ================== \n',
    );
    // ========= END - ZNetwork Merkle Tree =========

    // ========= START - ZZone Merkle Tree =========
    console.log(
        'START - ================== ZZone Merkle Tree ==================',
    );
    // Adding First leaf to zZoneMerkleTree at position 0
    const zZoneCommitment0 = await addLeafToZZoneRecordMerkleTree(
        1n,
        BigInt(
            13969057660566717294144404716327056489877917779406382026042873403164748884885n,
        ),
        BigInt(
            11069452135192839850369824221357904553346382352990372044246668947825855305207n,
        ),
        1n,
        1n,
        3n,
        1577058395n,
        10368000n,
        86400n,
        BigInt(1 * 10 ** 12),
        BigInt(1 * 10 ** 12),
        BigInt(1 * 10 ** 12),
        BigInt(
            1766847064778384329583297500742918515827483896875618958121606201292619775n,
        ),
        BigInt(1 * 10 ** 13),
        86400n,
    );

    console.log(`Computed commitment for leaf 0 is ${zZoneCommitment0}`);

    // get the proof for leaf at position 1
    const ZZoneMerkleProofAfterLeaf0 = await getPOEOfLeafInZZoneMerkleTree(0);
    console.log(
        `State of ZZone Merkle Tree after the insertion of 0 leaf`,
        ZZoneMerkleProofAfterLeaf0,
    );
    console.log(
        'END - ================== ZZone Merkle Tree ================== \n',
    );
    // ========= END - ZZone Merkle Tree =========

    // ========= START - ZAccount BlackList Merkle Tree =========
    console.log(
        'START - ================== ZAccount BlackList Merkle Tree ==================',
    );

    // All leafs are 0 which means none of the ZAccount is blacklisted.
    // If you want to blacklist any ZAccount find the index of that leaf and blacklist like below.
    // await addLeafToZAccountBlackListMerkleTree(0);

    // get the proof for leaf at position 0
    // const ZAccountBlackListMerkleProof =
    //     await getPOEOfLeafInZAccountBlackListMerkleTree(0);

    // Since we are not marking at any ZAccount as blacklisted root will be same as the initialised previously.
    console.log(
        `State of ZAccount Blacklist Tree`,
        zAccountBlackListMerkleTree.root,
    );

    console.log(
        'END - ================== ZAccount BlackList Merkle Tree ================== \n',
    );
    // ========= END - ZAccount BlackList Merkle Tree =========

    // ========= START - Static Merkle Root Computation =========
    // root of all the static merkle trees
    console.log(
        'START - ==================  Static Merkle Root Computation ================== ',
    );
    await computeStaticMerkleRoot(
        ZAssetMerkleProofAfterLeaf1.root,
        zAccountBlackListMerkleTree.root,
        ZNetworkMerkleProofAfterLeaf1.root,
        ZZoneMerkleProofAfterLeaf0.root,
        trustProviderMerkleProofAfterLeaf1.root,
    );
    console.log(
        'END - ================== Static Merkle Root Computation ================== \n',
    );
    // ========= END - Static Merkle Root Computation =========
}

main()
    .then(() => process.exit(0))
    .catch(err => {
        console.log(err);
        process.exit(1);
    });
