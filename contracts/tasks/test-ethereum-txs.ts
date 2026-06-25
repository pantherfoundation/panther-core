import {task} from 'hardhat/config';
import fs from 'fs';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

const DAO_MULTISIG = '0x505796f5bc290269d2522cf19135ad7aa60dfd77';
const FX_ROOT = '0xfe5e5D361b2ad62c541bAb87C45a0B9B018389a2';

/**
 * PIP-32: Test ethereum-transactions.json on forked Ethereum mainnet.
 *
 * IMPORTANT: HARDHAT_FORKING_BLOCK must be set to a recent Ethereum block number.
 * Forking Ethereum without a pinned block fails due to a Hardhat + Node.js v25 issue.
 *
 * Usage:
 *   HARDHAT_FORKING_URL="https://eth-mainnet.g.alchemy.com/v2/<KEY>" \
 *   HARDHAT_FORKING_ENABLED=true \
 *   HARDHAT_FORKING_BLOCK=<LATEST_ETH_BLOCK> \
 *   npx hardhat pip-32-test-ethereum
 *
 * Get the latest Ethereum block:
 *   cast block-number --rpc-url https://eth-mainnet.g.alchemy.com/v2/<KEY>
 */
task(
    'pip-32-test-ethereum',
    'Test ethereum-transactions.json on forked Ethereum mainnet',
).setAction(async (_, hre) => {
    // Warn if HARDHAT_FORKING_BLOCK is not set
    if (!process.env.HARDHAT_FORKING_BLOCK) {
        console.log('WARNING: HARDHAT_FORKING_BLOCK is not set.');
        console.log('Ethereum fork requires a pinned block number (Hardhat + Node.js v25 issue).');
        console.log('Set it to a recent Ethereum block, e.g.:');
        console.log('  HARDHAT_FORKING_BLOCK=24886000 npx hardhat pip-32-test-ethereum');
        console.log('');
    }

    const blockNumber = (await hre.ethers.provider.getBlock('latest')).number;
    console.log(`\n=== PIP-32 Ethereum TX Test ===`);
    console.log(`Forked block: ${blockNumber}\n`);

    // Verify we're on an Ethereum fork
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;
    if (chainId !== 1 && chainId !== 31337) {
        console.log(
            `WARNING: chainId=${chainId}, expected 1 (Ethereum) or 31337 (Hardhat fork)`,
        );
    }

    if (!fs.existsSync('ethereum-transactions.json')) {
        throw new Error(
            "ethereum-transactions.json not found. Run 'npx hardhat pip-32-bridge' then 'npx hardhat pip-32-ethereum' first.",
        );
    }

    const transactions = JSON.parse(
        fs.readFileSync('ethereum-transactions.json', 'utf-8'),
    );
    console.log(`Loaded ${transactions.length} transactions\n`);

    // Verify FxRoot has code (proves we're on a real Ethereum fork)
    const fxRootCode = await hre.ethers.provider.getCode(FX_ROOT);
    if (fxRootCode === '0x') {
        throw new Error(
            `FxRoot at ${FX_ROOT} has no code. Are you forking Ethereum mainnet?`,
        );
    }
    console.log(`FxRoot contract verified at ${FX_ROOT}`);

    // Impersonate DAO Multisig (msg.sender must be DAO Multisig for bridge auth on Polygon side)
    await hre.network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [DAO_MULTISIG],
    });
    await hre.network.provider.send('hardhat_setBalance', [
        DAO_MULTISIG,
        '0x3635C9ADC5DEA00000', // 1000 ETH
    ]);
    const daoSigner = await hre.ethers.getSigner(DAO_MULTISIG);
    console.log(`Impersonated DAO Multisig: ${DAO_MULTISIG}\n`);

    // Detect StateSender address from FxRoot storage slot 0
    const stateSenderAddr = await getStateSenderAddress(hre);
    console.log(`StateSender contract: ${stateSenderAddr}\n`);

    let allPassed = true;

    for (const tx of transactions) {
        console.log(
            `--- Tx #${tx.order}: ${tx.message} for ${tx.ownerToRemove} ---`,
        );
        console.log(`  Bridge nonce: ${tx.nonce}`);

        try {
            const txResponse = await daoSigner.sendTransaction({
                to: tx.to,
                value: tx.value,
                data: tx.data,
                gasLimit: 500000,
            });

            const receipt = await txResponse.wait();
            console.log(
                `  TX succeeded: ${receipt.transactionHash} (gas: ${receipt.gasUsed})`,
            );

            // Check for StateSynced event in receipt logs
            const stateSyncedTopic = hre.ethers.utils.id(
                'StateSynced(uint256,address,bytes)',
            );
            const stateSyncLog = receipt.logs.find(
                (log: any) => log.topics[0] === stateSyncedTopic,
            );

            if (stateSyncLog) {
                const stateId = hre.ethers.BigNumber.from(
                    stateSyncLog.topics[1],
                );
                console.log(`  StateSynced event emitted (stateId: ${stateId})`);
            } else {
                console.log(`  WARNING: No StateSynced event found`);
            }

            console.log(`  PASS\n`);
        } catch (err: any) {
            console.log(`  FAILED: ${err.message}\n`);
            allPassed = false;
        }
    }

    if (allPassed) {
        console.log(
            `=== All ${transactions.length} transactions executed successfully ===`,
        );
    } else {
        throw new Error('Some transactions failed. See output above.');
    }
});

async function getStateSenderAddress(
    hre: HardhatRuntimeEnvironment,
): Promise<string> {
    // FxRoot stores stateSender at slot 0 in standard FxPortal implementations
    const slot0 = await hre.ethers.provider.getStorageAt(FX_ROOT, 0);
    const addr = '0x' + slot0.slice(26);
    const code = await hre.ethers.provider.getCode(addr);
    if (code !== '0x') {
        return addr;
    }
    return 'unknown (could not auto-detect)';
}
