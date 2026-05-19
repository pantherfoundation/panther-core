// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {ethers} from 'hardhat';

const PAYMASTER_ADDRESS = '0x98d1EB3a69ddBcF57610Fe1c81C08C838AC8d262';

async function main() {
    console.log(`Fetching bundler config from ${PAYMASTER_ADDRESS}...\n`);

    const paymaster = await ethers.getContractAt(
        'PayMaster',
        PAYMASTER_ADDRESS,
    );

    const config = await paymaster.bundlerConfig();
    const depositThreshold = await paymaster.depositThreshold();

    console.log('PayMaster Configuration:');
    console.log('═══════════════════════════════════════════════════════');
    console.log(
        `Deposit Threshold:       ${ethers.utils.formatEther(
            depositThreshold,
        )} ETH`,
    );
    console.log('\nBundler Config:');
    console.log(`  Max Extra Gas:         ${config.maxExtraGas.toString()}`);
    console.log(
        `  Gas Price Markup %:    ${config.gasPriceMarkupPct.toString()} (${(
            config.gasPriceMarkupPct / 10000
        ).toFixed(2)}%)`,
    );
    console.log(
        `  Exchange Risk %:       ${config.exchangeRiskPct.toString()} (${(
            config.exchangeRiskPct / 10000
        ).toFixed(2)}%)`,
    );

    // Check if new field exists (upgraded contract)
    if (config.gasPriceMarkupFixed !== undefined) {
        console.log(
            `  Gas Price Markup Fixed: ${config.gasPriceMarkupFixed.toString()} wei (${ethers.utils.formatUnits(
                config.gasPriceMarkupFixed,
                'gwei',
            )} gwei)`,
        );
    }

    console.log('═══════════════════════════════════════════════════════');
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
