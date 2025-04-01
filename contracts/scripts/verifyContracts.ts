// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {run, deployments, network} from 'hardhat';
import {Deployment} from 'hardhat-deploy/dist/types';

async function main() {
    console.log(`Verifying contracts on ${network} network`);

    const allDeployments: Record<string, Deployment> = await deployments.all();

    for (const [name, deployment] of Object.entries(allDeployments)) {
        // Poseidon contracts have been deployed using their ABI. The actual
        // code is not available, so it's not possible to verify them.
        if (name.startsWith('Poseidon')) continue;

        if (deployment.address) {
            console.log(`Verifying ${name} at ${deployment.address}...`);

            try {
                await run('verify:verify', {
                    address: deployment.address,
                    constructorArguments: deployment.args || [],
                    libraries: deployment.libraries ? deployment.libraries : {},
                });
                console.log(`✅ Verified ${name} successfully.`);
            } catch (error: any) {
                if (error.message.toLowerCase().includes('already verified')) {
                    console.log(`ℹ️  ${name} is already verified.`);
                } else {
                    console.error(
                        `❌ Failed to verify ${name}:`,
                        error.message,
                    );
                }
            }
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error('Verification script failed:', error);
        process.exit(1);
    });
