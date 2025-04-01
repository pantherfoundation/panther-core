// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SaltedLockDataStruct} from '@panther-core/dapp/src/types/contracts/Vault';
import {ethers} from 'hardhat';

import {TokenType} from './token';

function composeExecData(data: SaltedLockDataStruct, vault: string): string {
    const ERR_INVALID_TOKEN_TYPE = 'Invalid token type';

    let execData: string;

    if (
        data.tokenType === TokenType.Erc20 ||
        data.tokenType === TokenType.Erc2612
    ) {
        execData = ethers.utils.hexConcat([
            ethers.utils
                .id('transferFrom(address,address,uint256)')
                .substr(0, 10),
            ethers.utils.defaultAbiCoder.encode(
                ['address', 'address', 'uint256'],
                [data.extAccount, vault, data.extAmount],
            ),
        ]);
    } else if (data.tokenType === TokenType.Erc721) {
        execData = ethers.utils.hexConcat([
            ethers.utils
                .id('safeTransferFrom(address,address,uint256)')
                .substr(0, 10),
            ethers.utils.defaultAbiCoder.encode(
                ['address', 'address', 'uint256'],
                [data.extAccount, vault, data.tokenId],
            ),
        ]);
    } else if (data.tokenType === TokenType.Erc1155) {
        execData = ethers.utils.hexConcat([
            ethers.utils
                .id('safeTransferFrom(address,address,uint256,uint256,bytes)')
                .substr(0, 10),
            ethers.utils.defaultAbiCoder.encode(
                ['address', 'address', 'uint256', 'uint256', 'bytes'],
                [data.extAccount, vault, data.tokenId, data.extAmount, '0x'],
            ),
        ]);
    } else if (data.tokenType === TokenType.Native) {
        throw new Error('use vault.getEscrowAddress(salt,sender)');
    } else {
        throw new Error(ERR_INVALID_TOKEN_TYPE);
    }

    return execData;
}

export {composeExecData, TokenType};
