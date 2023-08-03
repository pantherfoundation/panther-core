import {TypedDataDomain} from '@ethersproject/abstract-signer';
import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {fromRpcSig} from 'ethereumjs-util';
import {utils} from 'ethers';
import {task} from 'hardhat/config';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

import {ProvidersKeys} from '../../types/contracts/ProvidersKeys';

const TASK_ZACCOUNT_REGISTER = 'key:register';

async function genSignature(
    hre: HardhatRuntimeEnvironment,
    providersKeys: ProvidersKeys,
    pubRootSpendingKey: string,
    expiryDate: string,
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

    console.log({
        name,
        version,
        chainId,
        verifyingContract,
        providersKeysVersion,
        salt,
    });

    const types = {
        Registration: [
            {name: 'pubRootSpendingKey', type: 'bytes32'},
            {name: 'expiryDate', type: 'uint32'},
            {name: 'version', type: 'uint256'},
        ],
    };

    const value = {
        pubRootSpendingKey,
        expiryDate,
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

function getSiblings() {
    return [
        '0x0667764c376602b72ef22218e1673c2cc8546201f9a77807570b3e5de137680d',
        '0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4',
        '0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8',
        '0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c',
        '0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800',
        '0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f',
        '0x2e99dc37b0a4f107b20278c26562b55df197e0b3eb237ec672f4cf729d159b69',
        '0x225624653ac89fe211c0c3d303142a4caf24eb09050be08c33af2e7a1e372a0f',
        '0x276c76358db8af465e2073e4b25d6b1d83f0b9b077f8bd694deefe917e2028d7',
        '0x09df92f4ade78ea54b243914f93c2da33414c22328a73274b885f32aa9dea718',
        '0x1c78b565f2bfc03e230e0cf12ecc9613ab8221f607d6f6bc2a583ccd690ecc58',
        '0x2879d62c83d6a3af05c57a4aee11611a03edec5ff8860b07de77968f47ff1c5f',
        '0x28ad970560de01e93b613aabc930fcaf087114743909783e3770a1ed07c2cde6',
        '0x27ca60def9dd0603074444029cbcbeaa9dbe77668479ac1db738bb892d9f3b6d',
        '0x28e4c1e90bbfa69de93abf6cbdc7cd1c0753a128e83b2b3afe34e0471a13ff55',
        '0x1b89c44a9f153266ad5bf754d4b252c26acba7d21fc661b94dc0618c6a82f49c',
    ];
}

task(TASK_ZACCOUNT_REGISTER, 'Update the panther pool exit time')
    .addParam('contract', 'Z Account registry address') // 0xc6B27Ad7D1a33777F2d9C114f3e3e318CB455cC3

    .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
        const [signer] = await hre.ethers.getSigners();

        const providersKeys = (await hre.ethers.getContractAt(
            'ProvidersKeys',
            taskArgs.contract,
        )) as ProvidersKeys;

        await providersKeys.updateTreeRootUpdatingAllowedStatus(true);

        // console.log('adding keyring');
        // const addTx = await providersKeys.addKeyring(signer.address, 10);
        // const addRes = await addTx.wait();
        // console.log('Transaction is confirmed.', addRes);

        const pubKeyPacked =
            '0x2cf8bc5fc9c122f6cc883988fd57e45ad086ec2785d2dfbfa85032373f90aca2';
        const expiryDate = '1735689600';

        const {v, r, s} = await genSignature(
            hre,
            providersKeys,
            pubKeyPacked,
            expiryDate,
            signer,
        );

        const pubKey = {
            x: '9487832625653172027749782479736182284968410276712116765581383594391603612850',
            y: '20341243520484112812812126668555427080517815150392255522033438580038266039458',
        };

        const tx = await providersKeys.registerKey(
            pubKey,
            expiryDate,
            getSiblings(),
            v,
            r,
            s,
        );

        const res = await tx.wait();
        console.log('Transaction is confirmed.', res);
    });
