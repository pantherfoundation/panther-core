import {task} from 'hardhat/config';
import fs from 'fs';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

// ===== ADDRESSES =====
const OWNER_SAFE_DAO = '0x026a024b13B4Ca23897ad578264C0ec543f904b9';
const NEW_SIGNER = '0x208Fb9169BBec5915722e0AfF8B0eeEdaBf8a6f0';
const SIGNER_1 = '0xFee6D2Cb5816282D853fba79cB9C8b5EDB7908Cd';
const SIGNER_2 = '0xb83A3094272B6425f89BB5590b48928e2374eE11';
const DAO_MULTISIG = '0x505796f5bc290269d2522cf19135ad7aa60dfd77';
const FX_CHILD = '0x8397259c983751daf40400790063935a11afa28a';
const FX_ROOT = '0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2';
const MATIC_BRIDGE_MODULE = '0x4A4FC40d2475f493EcA3Ec436b924237AA1b0a76';
const CHAIN_ID = 137;

// ===== ABIs =====
const safeAbi = [
    'function changeThreshold(uint256 _threshold)',
    'function addOwnerWithThreshold(address owner, uint256 _threshold)',
    'function removeOwner(address prevOwner, address owner, uint256 _threshold)',
    'function execTransaction(address to, uint256 value, bytes data, uint8 operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, bytes signatures) payable returns (bool)',
    'function approveHash(bytes32 hashToApprove)',
    'function getOwners() view returns (address[])',
    'function getThreshold() view returns (uint256)',
    'function nonce() view returns (uint256)',
];

const maticBridgeModuleAbi = [
    'function processMessageFromRoot(uint256 stateId, address rootMessageSender, bytes calldata data)',
    'function nonce() view returns (uint256)',
];

const fxRootAbi = [
    'function sendMessageToChild(address receiver, bytes calldata data)',
];

const SAFE_TX_TYPEHASH = [
    {type: 'address', name: 'to'},
    {type: 'uint256', name: 'value'},
    {type: 'bytes', name: 'data'},
    {type: 'uint8', name: 'operation'},
    {type: 'uint256', name: 'safeTxGas'},
    {type: 'uint256', name: 'baseGas'},
    {type: 'uint256', name: 'gasPrice'},
    {type: 'address', name: 'gasToken'},
    {type: 'address', name: 'refundReceiver'},
    {type: 'uint256', name: 'nonce'},
];

// ===== HELPERS =====

const impersonate = async (
    hre: HardhatRuntimeEnvironment,
    addr: string,
): Promise<SignerWithAddress> => {
    await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [addr],
    });
    return await hre.ethers.getSigner(addr);
};

const addBalance = async (hre: HardhatRuntimeEnvironment, account: string) => {
    await hre.network.provider.send('hardhat_setBalance', [
        account,
        '0x3635C9ADC5DEA00000', // 1000 ETH
    ]);
};

const buildApprovalSignature = (signerAddr: string): string => {
    const addr = signerAddr.slice(2).toLowerCase();
    return (
        '000000000000000000000000' +
        addr +
        '0000000000000000000000000000000000000000000000000000000000000000' +
        '01'
    );
};

const hashSafeTx = (hre: HardhatRuntimeEnvironment, safeTx: any) => {
    return hre.ethers.utils._TypedDataEncoder.hash(
        {verifyingContract: OWNER_SAFE_DAO, chainId: CHAIN_ID},
        {SafeTx: SAFE_TX_TYPEHASH},
        safeTx,
    );
};

const buildSafeTx = (
    hre: HardhatRuntimeEnvironment,
    data: string,
    nonce: any,
) => ({
    to: OWNER_SAFE_DAO,
    value: 0,
    data,
    operation: 0,
    safeTxGas: 0,
    baseGas: 0,
    gasPrice: 0,
    gasToken: hre.ethers.constants.AddressZero,
    refundReceiver: hre.ethers.constants.AddressZero,
    nonce,
});

// ===== POLYGON FORK: Simulate signer removal via MaticBridgeModule =====

task(
    'pip-32-bridge',
    'Simulate signer removal via MaticBridgeModule on forked Polygon',
).setAction(async (_, hre) => {
    const blockNumber = (await hre.ethers.provider.getBlock('latest')).number;
    console.log(`\n=== PIP-32 Bridge Simulation (block ${blockNumber}) ===\n`);

    // --- Verify preconditions ---
    const ownerSafe = await hre.ethers.getContractAt(safeAbi, OWNER_SAFE_DAO);
    const maticBridgeModule = await hre.ethers.getContractAt(
        maticBridgeModuleAbi,
        MATIC_BRIDGE_MODULE,
    );

    const owners = await ownerSafe.getOwners();
    const threshold = await ownerSafe.getThreshold();
    const safeNonce = await ownerSafe.nonce();
    const bridgeNonce = await maticBridgeModule.nonce();

    console.log(`ownerSafeDao threshold: ${threshold}`);
    console.log(`ownerSafeDao nonce:     ${safeNonce}`);
    console.log(`ownerSafeDao owners:    ${owners.join(', ')}`);
    console.log(`bridgeModule nonce:     ${bridgeNonce}`);

    if (threshold.toString() !== '1') {
        throw new Error(`Expected threshold=1, got ${threshold}`);
    }
    if (
        !owners
            .map((o: string) => o.toLowerCase())
            .includes(NEW_SIGNER.toLowerCase())
    ) {
        throw new Error(`newSigner ${NEW_SIGNER} is not an owner`);
    }
    if (
        !owners
            .map((o: string) => o.toLowerCase())
            .includes(SIGNER_1.toLowerCase())
    ) {
        throw new Error(`signer1 ${SIGNER_1} not found — already removed?`);
    }
    if (
        !owners
            .map((o: string) => o.toLowerCase())
            .includes(SIGNER_2.toLowerCase())
    ) {
        throw new Error(`signer2 ${SIGNER_2} not found — already removed?`);
    }
    console.log(`\nPreconditions OK\n`);

    // --- Impersonate fxChild ---
    const fxChildSigner = await impersonate(hre, FX_CHILD);
    await addBalance(hre, fxChildSigner.address);

    // --- Remove signers via bridge ---
    const allBridgeMessages: any[] = [];
    let currentSafeNonce = safeNonce;
    let currentBridgeNonce = bridgeNonce;

    // Remove SIGNER_1 (prevOwner = NEW_SIGNER based on linked list order)
    console.log(`--- Removing ${SIGNER_1} via bridge ---`);
    await removeSignerViaBridge(
        hre,
        ownerSafe,
        maticBridgeModule,
        fxChildSigner,
        NEW_SIGNER,
        SIGNER_1,
        currentSafeNonce,
        currentBridgeNonce,
        1,
        allBridgeMessages,
    );
    currentSafeNonce = currentSafeNonce.add(1);
    currentBridgeNonce = currentBridgeNonce.add(2);

    // Remove SIGNER_2 (prevOwner = NEW_SIGNER after SIGNER_1 removal)
    console.log(`\n--- Removing ${SIGNER_2} via bridge ---`);
    await removeSignerViaBridge(
        hre,
        ownerSafe,
        maticBridgeModule,
        fxChildSigner,
        NEW_SIGNER,
        SIGNER_2,
        currentSafeNonce,
        currentBridgeNonce,
        1,
        allBridgeMessages,
    );

    // --- Verify final state ---
    const finalOwners = await ownerSafe.getOwners();
    const finalThreshold = await ownerSafe.getThreshold();
    console.log(`\n=== Final State ===`);
    console.log(`Owners:    ${finalOwners.join(', ')}`);
    console.log(`Threshold: ${finalThreshold}`);

    if (
        finalOwners.length !== 1 ||
        finalOwners[0].toLowerCase() !== NEW_SIGNER.toLowerCase()
    ) {
        throw new Error(`Unexpected final owners: ${finalOwners}`);
    }
    console.log({finalOwners});
    console.log(`\nAll old signers removed. Only ${NEW_SIGNER} remains.`);

    // --- Save bridge messages ---
    fs.writeFileSync(
        'bridge-messages.json',
        JSON.stringify(allBridgeMessages, null, 2),
    );
    console.log(`\nBridge messages saved to bridge-messages.json`);
});

// ===== ETHEREUM FORK: Generate FxRoot calldata for Snapshot proposal =====

task(
    'pip-32-ethereum',
    'Generate FxRoot calldata for Snapshot proposal',
).setAction(async (_, hre) => {
    console.log('=== Generating Ethereum FxRoot Transactions ===\n');

    if (!fs.existsSync('bridge-messages.json')) {
        console.log('bridge-messages.json not found.');
        console.log("Run 'npx hardhat pip-32-bridge' on a Polygon fork first.");
        return;
    }

    const bridgeMessages = JSON.parse(
        fs.readFileSync('bridge-messages.json', 'utf-8'),
    );

    const fxRoot = await hre.ethers.getContractAt(fxRootAbi, FX_ROOT);
    const ethereumTransactions: any[] = [];

    for (let i = 0; i < bridgeMessages.length; i++) {
        const msg = bridgeMessages[i];

        console.log(
            `Tx ${i + 1}/${bridgeMessages.length}: ${msg.message} for ${
                msg.ownerToRemove
            }`,
        );
        console.log(`  Bridge nonce: ${msg.nonce}`);

        const calldata = await fxRoot.populateTransaction.sendMessageToChild(
            MATIC_BRIDGE_MODULE,
            msg.encodedData,
        );

        ethereumTransactions.push({
            order: i + 1,
            message: msg.message,
            ownerToRemove: msg.ownerToRemove,
            nonce: msg.nonce,
            to: FX_ROOT,
            value: 0,
            data: calldata.data,
        });
    }

    // Save JSON
    fs.writeFileSync(
        'ethereum-transactions.json',
        JSON.stringify(ethereumTransactions, null, 2),
    );

    // Generate tx-data.txt
    const lines: string[] = [];
    lines.push(
        '** PIP-32: Transition ownerSafeDao to newSigner Safe Control **',
    );
    lines.push('');
    lines.push('** Addresses **');
    lines.push('');
    lines.push('Panther contracts on Ethereum:');
    lines.push(`    - DAO_Multisig@eth: ${DAO_MULTISIG}`);
    lines.push(`    - FxRoot@eth: ${FX_ROOT}`);
    lines.push('');
    lines.push('Panther contracts on Polygon:');
    lines.push(`    - ownerSafeDao@matic: ${OWNER_SAFE_DAO}`);
    lines.push(`    - newSigner (DAO Safe)@matic: ${NEW_SIGNER}`);
    lines.push(`    - MaticBridgeModule@matic: ${MATIC_BRIDGE_MODULE}`);
    lines.push('');
    lines.push('** Transactions for the Snapshot **');
    lines.push('');
    lines.push('Transactions Overview');
    lines.push(
        `   # Remove old signers (${SIGNER_1}, ${SIGNER_2}) from ownerSafeDao and leave only newSigner Safe as owner via cross-chain governance`,
    );
    for (const tx of ethereumTransactions) {
        lines.push(
            `    ${tx.order}. FxRoot@eth::sendMessageToChild(MaticBridgeModule, encodedData) // ${tx.message} for ${tx.ownerToRemove}`,
        );
    }
    lines.push('');
    lines.push('** Batch #1 **');
    lines.push('========');

    for (const tx of ethereumTransactions) {
        lines.push('');
        lines.push(
            `    Tx #${tx.order}: ${tx.message} for ${tx.ownerToRemove}`,
        );
        lines.push('        To:');
        lines.push(`            ${tx.to} // FxRoot@eth`);
        lines.push('        Value:');
        lines.push('            0');
        lines.push('        Data:');
        lines.push(`            ${tx.data}`);
    }
    lines.push('');

    fs.writeFileSync('tx-data.txt', lines.join('\n'));

    console.log('\nSaved: ethereum-transactions.json');
    console.log('Saved: tx-data.txt');
    console.log(
        '\nThese transactions should be executed on Ethereum mainnet by the DAO multisig.',
    );
});

// ===== BRIDGE REMOVAL LOGIC =====

const removeSignerViaBridge = async (
    hre: HardhatRuntimeEnvironment,
    ownerSafe: any,
    maticBridgeModule: any,
    fxChildSigner: SignerWithAddress,
    prevOwner: string,
    ownerToRemove: string,
    ownerSafeNonce: any,
    bridgeNonce: any,
    newThreshold: number,
    allBridgeMessages: any[],
) => {
    // Build the removeOwner Safe transaction
    const removeOwnerData = ownerSafe.interface.encodeFunctionData(
        'removeOwner',
        [prevOwner, ownerToRemove, newThreshold],
    );
    const safeTx = buildSafeTx(hre, removeOwnerData, ownerSafeNonce);
    const txHash = hashSafeTx(hre, safeTx);

    console.log(`  Safe nonce:   ${ownerSafeNonce}`);
    console.log(`  Bridge nonce: ${bridgeNonce}`);
    console.log(`  Safe txHash:  ${txHash}`);

    // ---- Bridge Message 1: approveHash ----
    const approveHashData = ownerSafe.interface.encodeFunctionData(
        'approveHash',
        [txHash],
    );

    const encodedMsg1 = hre.ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
        [OWNER_SAFE_DAO, 0, approveHashData, 0, bridgeNonce],
    );

    allBridgeMessages.push({
        message: 'Approve removal hash',
        ownerToRemove,
        stateId: 0,
        rootMessageSender: DAO_MULTISIG,
        encodedData: encodedMsg1,
        nonce: bridgeNonce.toString(),
        txHash,
    });

    console.log(`  [Bridge Msg 1] Approving hash...`);
    const bridgeTx1 = await maticBridgeModule
        .connect(fxChildSigner)
        .processMessageFromRoot(0, DAO_MULTISIG, encodedMsg1, {
            gasLimit: 500000,
        });
    await bridgeTx1.wait();
    console.log(`  Hash approved`);

    // ---- Bridge Message 2: execTransaction ----
    const signatureBytes = buildApprovalSignature(NEW_SIGNER);
    const execTransactionData = ownerSafe.interface.encodeFunctionData(
        'execTransaction',
        [
            safeTx.to,
            safeTx.value,
            safeTx.data,
            safeTx.operation,
            safeTx.safeTxGas,
            safeTx.baseGas,
            safeTx.gasPrice,
            safeTx.gasToken,
            safeTx.refundReceiver,
            `0x${signatureBytes}`,
        ],
    );

    const encodedMsg2 = hre.ethers.utils.defaultAbiCoder.encode(
        ['address', 'uint256', 'bytes', 'uint8', 'uint256'],
        [OWNER_SAFE_DAO, 0, execTransactionData, 0, bridgeNonce.add(1)],
    );

    allBridgeMessages.push({
        message: 'Execute removal',
        ownerToRemove,
        stateId: 0,
        rootMessageSender: DAO_MULTISIG,
        encodedData: encodedMsg2,
        nonce: bridgeNonce.add(1).toString(),
        safeTx,
    });

    console.log(`  [Bridge Msg 2] Executing removeOwner...`);
    const bridgeTx2 = await maticBridgeModule
        .connect(fxChildSigner)
        .processMessageFromRoot(0, DAO_MULTISIG, encodedMsg2, {
            gasLimit: 500000,
        });
    const receipt = await bridgeTx2.wait();
    console.log(`  ${ownerToRemove} removed (block ${receipt.blockNumber})`);
};
