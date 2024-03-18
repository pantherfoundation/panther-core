// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

// eslint-disable-next-line import/named
import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {fromRpcSig} from 'ethereumjs-util';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

import {ProvidersKeys, G1PointStruct} from '../types/contracts/ProvidersKeys';

export async function genSignatureForRegisterProviderKey(
    hre: HardhatRuntimeEnvironment,
    providersKeys: ProvidersKeys,
    keyringId: string,
    pubRootSpendingKey: G1PointStruct,
    expiryDate: string,
    proofSiblings: string[],
    signer: SignerWithAddress,
): Promise<{
    v: number;
    r: Buffer;
    s: Buffer;
}> {
    const name = await providersKeys.EIP712_NAME();
    const version = await providersKeys.EIP712_VERSION();
    const chainId = (await hre.ethers.provider.getNetwork()).chainId;

    const salt = await providersKeys.EIP712_SALT();
    const verifyingContract = providersKeys.address;
    const providersKeysVersion = await providersKeys.KEYRING_VERSION();

    const types = {
        RegisterKey: [
            {name: 'keyringId', type: 'uint16'},
            {name: 'pubRootSpendingKey', type: 'G1Point'},
            {name: 'expiryDate', type: 'uint32'},
            {name: 'proofSiblings', type: 'bytes32[]'},
            {name: 'version', type: 'uint256'},
        ],
        G1Point: [
            {name: 'x', type: 'uint256'},
            {name: 'y', type: 'uint256'},
        ],
    };

    const value = {
        keyringId,
        pubRootSpendingKey,
        expiryDate,
        proofSiblings,
        version: providersKeysVersion,
    };

    const domain: TypedDataDomain = {
        name,
        version,
        chainId,
        verifyingContract,
        salt,
    };

    const signature = await signer._signTypedData(domain, types, value);
    return fromRpcSig(signature); // does nothing other that splitting the signature string
}
