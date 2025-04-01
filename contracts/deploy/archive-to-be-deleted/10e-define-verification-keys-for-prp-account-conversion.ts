// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getContractEnvVariable} from '../../lib/deploymentHelpers';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    // A single base filename or the semicolon-delimited list of base filenames expected
    const envName = getContractEnvVariable(hre, 'VERIFICATION_KEYS');
    let currentList = process.env[envName] || '';

    // VK files (single base filename or semicolon-delimited list) to be in currentList
    const keyFilesList = 'VK_prpAccountConversion.json';

    if (!currentList.includes(keyFilesList)) {
        if (currentList && !currentList.endsWith(';')) currentList += ';';
        process.env[envName] = currentList + keyFilesList;
    }
};
export default func;

func.tags = ['prp-account-conversion-vk', 'vk-list', 'forest', 'protocol'];
