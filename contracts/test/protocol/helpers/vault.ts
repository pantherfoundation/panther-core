// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {composeExecData} from '../../../lib/composeExecData';

export function composeERC20SenderStealthAddress(
    lockData: SaltedLockDataStruct,
    vault: string,
): string {
    const execData2 = composeExecData(lockData, vault);

    const initCode2 = ethers.utils.solidityPack(
        ['bytes', 'address', 'bytes'],
        [
            '0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300',
            lockData.token,
            execData2,
        ],
    );

    return ethers.utils.getCreate2Address(
        vault,
        lockData.salt,
        ethers.utils.keccak256(initCode2),
    );
}
