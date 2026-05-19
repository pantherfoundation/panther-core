#!/usr/bin/env node

import * as fs from 'fs';
import * as path from 'path';

interface SafeTransaction {
    to: string;
    data: string;
    operation: string;
    value: string;
}

function findTransactionFilesWithPrefix(
    transactionsDir: string,
    prefix: string,
): string[] {
    if (!fs.existsSync(transactionsDir)) {
        return [];
    }

    const files = fs.readdirSync(transactionsDir);
    return files
        .filter(
            file =>
                file.startsWith(prefix) &&
                file.endsWith('-polygon.json') &&
                !file.startsWith('batch-'),
        )
        .sort()
        .map(file => path.join(transactionsDir, file));
}

function main() {
    const args = process.argv.slice(2);
    if (args.length !== 1) {
        console.error(
            'Usage: node scripts/batch-safe-transactions.ts <prefix>',
        );
        console.error('Example: node scripts/batch-safe-transactions.ts 04a');
        process.exit(1);
    }

    const prefix = args[0];
    const network = 'polygon';

    console.log(`Batching transactions for prefix: ${prefix}`);
    console.log(`Network: ${network}`);

    const transactionsDir = path.join(
        __dirname,
        '../deployments/safe-transactions',
    );
    const transactionFiles = findTransactionFilesWithPrefix(
        transactionsDir,
        prefix,
    );

    if (transactionFiles.length === 0) {
        console.log(
            `No transaction files found with prefix: ${prefix} for network: ${network}`,
        );
        return;
    }

    console.log(`Found ${transactionFiles.length} transaction files:`);
    transactionFiles.forEach(filePath => {
        console.log(`  - ${path.basename(filePath)}`);
    });

    const allTransactions: SafeTransaction[] = [];

    for (const filePath of transactionFiles) {
        try {
            const fileContent = fs.readFileSync(filePath, 'utf8');
            const transaction = JSON.parse(fileContent);
            allTransactions.push(transaction);
            console.log(`  Loaded transaction from ${path.basename(filePath)}`);
        } catch (error) {
            console.error(`Error reading ${filePath}:`, error);
            throw error;
        }
    }

    if (allTransactions.length === 0) {
        console.log(`No transactions loaded`);
        return;
    }

    const batchedTransaction = {
        version: '1.0',
        chainId: '137', // Polygon mainnet
        createdAt: Date.now(),
        meta: {
            name: `Batched ${prefix}`,
            description: `${allTransactions.length} transactions`,
            txBuilderVersion: '1.16.5',
        },
        transactions: allTransactions,
    };

    const filename = `batched-${prefix}-${network}.json`;
    const outputFile = path.join(transactionsDir, filename);

    fs.writeFileSync(outputFile, JSON.stringify(batchedTransaction, null, 2));
    console.log(
        `Batched ${allTransactions.length} transactions saved to: ${outputFile}`,
    );
}

main();
