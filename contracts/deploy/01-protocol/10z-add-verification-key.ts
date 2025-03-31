// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {promises} from 'fs';
import {basename, join} from 'path';

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {isLocal} from '../../lib/checkNetwork';
import {
    deployContentDeterministically,
    getContractEnvVariable,
    reuseEnvAddress,
    setDeterministicDeploymentProxy,
} from '../../lib/deploymentHelpers';
import {encodeVerificationKey} from '../../lib/encodeVerificationKey';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    await setDeterministicDeploymentProxy(hre);

    // Folder to upload verification keys from
    const vkFolderPath =
        process.env[
            `${getContractEnvVariable(hre, 'VERIFICATION_KEYS_FOLDER')}`
        ] ||
        (isLocal(hre)
            ? join(__dirname, '../../test/protocol/data/verificationKeys/')
            : '');
    if (!vkFolderPath) throw 'Undefined VERIFICATION_KEYS_FOLDER_<network>';

    const vkFilesList =
        process.env[`${getContractEnvVariable(hre, 'VERIFICATION_KEYS')}`] ||
        '';
    if (!vkFilesList) throw 'Undefined VERIFICATION_KEYS_<network>';

    const vkFiles = vkFilesList
        // A single name or the semicolon-delimited list expected
        .split(';')
        // Full path
        .map(f => join(vkFolderPath, f));

    for await (const vkFile of vkFiles) {
        const envName = getContractEnvVariable(
            hre,
            basename(vkFile).toUpperCase().replace('.JSON', ''),
        );
        if (reuseEnvAddress(hre, `${envName}`)) {
            continue;
        }

        const verificationKey = JSON.parse(
            await promises.readFile(vkFile, {encoding: 'utf8'}),
        );
        if (!verificationKey) {
            console.log(
                `No verification key was found for ${envName}, skip adding key...`,
            );
            continue;
        }

        const encodedVerificationKey = encodeVerificationKey(verificationKey);

        const {pointer, isReused} = await deployContentDeterministically(
            hre,
            encodedVerificationKey,
        );

        process.env[envName] = pointer;

        console.log(
            `Verification key ${envName} ${
                isReused ? 'reused' : 'deployed'
            } at ${pointer}`,
        );
    }
};
export default func;

func.tags = ['add-verification-key', 'forest', 'protocol'];
func.dependencies = ['check-params', 'vk-list'];
