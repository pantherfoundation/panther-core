// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {ethers} from 'hardhat';

import {getBlockTimestamp} from '../../../../lib/provider';
import {SnarkProofStruct} from '../../../../types/contracts/IPantherPoolV1';

const getSnarkFriendlyBytes = (length = 32) => {
    return ethers.BigNumber.from(ethers.utils.randomBytes(length))
        .mod(SNARK_FIELD_SIZE)
        .toString();
};

export const depositInputs = async () => {
    const chainId = (await ethers.provider.getNetwork()).chainId;

    return {
        extraInputsHash: getSnarkFriendlyBytes(), // MAIN_EXTRA_INPUT_HASH_IND
        depositAmount: ethers.utils.parseEther('1000'), // MAIN_DEPOSIT_AMOUNT_IND
        withdrawAmount: '0', // MAIN_WITHDRAW_AMOUNT_IND
        addedAmountZkp: '0', // MAIN_ADDED_AMOUNT_ZKP_IND
        token: ethers.Wallet.createRandom().address, // MAIN_TOKEN_IND
        tokenId: '0', // MAIN_TOKEN_ID_IND
        spendTime: ((await getBlockTimestamp()) - 60).toString(), // MAIN_SPEND_TIME_IND
        zAssetUtxoInNullifier1: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_IN_NULLIFIER_1_IND
        zAssetUtxoInNullifier2: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_IN_NULLIFIER_2_IND
        zAccountUtxoInNullifier: getSnarkFriendlyBytes(), // MAIN_ZACCOUNT_UTXO_IN_NULLIFIER_IND
        zZoneDataEscrowEphimeralPubKeyAx: getSnarkFriendlyBytes(), // MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
        zZoneDataEscrowEncryptedMessageAx: getSnarkFriendlyBytes(), // MAIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND
        kytDepositSignedMessageSender: getSnarkFriendlyBytes(), // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER_IND
        kytDepositSignedMessageReceiver: getSnarkFriendlyBytes(), // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER_IND
        kytDepositSignedMessageHash: getSnarkFriendlyBytes(), // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND
        kytWithdrawSignedMessageSender: getSnarkFriendlyBytes(), // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND
        kytWithdrawSignedMessageReceiver: getSnarkFriendlyBytes(), // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER_IND
        kytWithdrawSignedMessageHash: getSnarkFriendlyBytes(), // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND
        dataEscrowEphimeralPubKeyAx: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
        dataEscrowEncryptedMessageAx1: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX0_IND
        dataEscrowEncryptedMessageAx2: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX1_IND
        dataEscrowEncryptedMessageAx3: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX2_IND
        dataEscrowEncryptedMessageAx4: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX3_IND
        dataEscrowEncryptedMessageAx5: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX4_IND
        dataEscrowEncryptedMessageAx6: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX5_IND
        dataEscrowEncryptedMessageAx7: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX6_IND
        dataEscrowEncryptedMessageAx8: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX7_IND
        dataEscrowEncryptedMessageAx9: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX8_IND
        dataEscrowEncryptedMessageAx10: getSnarkFriendlyBytes(), // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX9_IND
        daoDataEscrowEphimeralPubKeyAx: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
        creationTime: (await getBlockTimestamp()).toString(),
        // daoDataEscrowEncryptedMessageAx1: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_1
        daoDataEscrowEncryptedMessageAx2: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_2
        daoDataEscrowEncryptedMessageAx3: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_3
        utxoOutCreateTime: ((await getBlockTimestamp()) + 60).toString(), // MAIN_UTXO_OUT_CREATE_TIME_IND
        zAssetUtxoOutCommitment1: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_OUT_COMMITMENT_1_IND
        zNetworkChainId: chainId, // MAIN_ZNETWORK_CHAIN_ID_IND
        staticMerkleRoot: ethers.BigNumber.from(0).toString(), // MAIN_STATIC_MERKLE_ROOT_IND
        zAssetUtxoOutCommitment2: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_OUT_COMMITMENT_2_IND
        zAccountUtxoOutCommitment: getSnarkFriendlyBytes(), // MAIN_ZACCOUNT_UTXO_OUT_COMMITMENT_IND
        chargedAmountZkp: ethers.utils.parseEther('1'), // MAIN_CHARGED_AMOUNT_ZKP_IND
        forestMerkleRoot: getSnarkFriendlyBytes(), // MAIN_FOREST_MERKLE_ROOT_IND
        saltHash: getSnarkFriendlyBytes(), // MAIN_SALT_HASH_IND
        magicalConstraint: getSnarkFriendlyBytes(), // MAIN_MAGICAL_CONSTRAINT_IND
    };
};

export async function generatezAssetSwapTestInputs(
    tokenIn: string,
    tokenOut: string,
    withdrawAmount: string,
    depositAmount: string,
) {
    const getBlockTimestamp = async () => {
        // Mock or actual implementation to fetch the current block timestamp
        return Math.floor(Date.now() / 1000);
    };

    const chainId = (await ethers.provider.getNetwork()).chainId;

    return {
        extraInputsHash: await getSnarkFriendlyBytes(), // inputs[0]
        depositAmount: depositAmount, // inputs[1]
        withdrawAmount: withdrawAmount, // inputs[2]
        addedAmountZkp: '0', // inputs[3]
        tokenIn: tokenIn, // inputs[4]
        tokenOut: tokenOut, // inputs[5]
        tokenInId: '0', // inputs[6]
        tokenOutId: '0', // inputs[7]
        zAssetInScale: '1000000', // inputs[8]F
        zAssetOutScale: '1000000', // inputs[9]
        spendTime: ((await getBlockTimestamp()) - 3600).toString(), // inputs[10]
        zAssetUtxoInNullifier1: await getSnarkFriendlyBytes(), // inputs[11]
        zAssetUtxoInNullifier2: await getSnarkFriendlyBytes(), // inputs[12]
        zAccountUtxoInNullifier: await getSnarkFriendlyBytes(), // inputs[13]
        zZoneDataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[14]
        zZoneDataEscrowEncryptedMessageAx: await getSnarkFriendlyBytes(), // inputs[15]
        kytDepositSignedMessageSender: await getSnarkFriendlyBytes(), // inputs[16]
        kytDepositSignedMessageReceiver: await getSnarkFriendlyBytes(), // inputs[17]
        kytDepositSignedMessageHash: await getSnarkFriendlyBytes(), // inputs[18]
        kytWithdrawSignedMessageSender: await getSnarkFriendlyBytes(), // inputs[19]
        kytWithdrawSignedMessageReceiver: await getSnarkFriendlyBytes(), // inputs[20]
        kytWithdrawSignedMessageHash: await getSnarkFriendlyBytes(), // inputs[21]
        dataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[22]
        dataEscrowEncryptedMessageAx1: await getSnarkFriendlyBytes(), // inputs[23]
        dataEscrowEncryptedMessageAx2: await getSnarkFriendlyBytes(), // inputs[24]
        dataEscrowEncryptedMessageAx3: await getSnarkFriendlyBytes(), // inputs[25]
        dataEscrowEncryptedMessageAx4: await getSnarkFriendlyBytes(), // inputs[26]
        dataEscrowEncryptedMessageAx5: await getSnarkFriendlyBytes(), // inputs[27]
        dataEscrowEncryptedMessageAx6: await getSnarkFriendlyBytes(), // inputs[28]
        dataEscrowEncryptedMessageAx7: await getSnarkFriendlyBytes(), // inputs[29]
        dataEscrowEncryptedMessageAx8: await getSnarkFriendlyBytes(), // inputs[30]
        daoDataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[31]
        mainDaoDataEscrowEncryptedMessageAx1: await getSnarkFriendlyBytes(), // inputs[32]
        mainDaoDataEscrowEncryptedMessageAx2: await getSnarkFriendlyBytes(), // inputs[33]
        mainDaoDataEscrowEncryptedMessageAx3: await getSnarkFriendlyBytes(), // inputs[34]
        utxoOutCreateTime: ((await getBlockTimestamp()) + 3600).toString(), // inputs[35]
        zAssetUtxoOutCommitment1: await getSnarkFriendlyBytes(), // inputs[36]
        zAssetUtxoOutCommitment2: await getSnarkFriendlyBytes(), // inputs[37]
        zAccountUtxoOutCommitment: await getSnarkFriendlyBytes(), // inputs[38]
        chargedAmountZkp: ethers.utils.parseEther('1'), // inputs[39]
        zNetworkChainId: chainId, // inputs[40]
        staticMerkleRoot: await getSnarkFriendlyBytes(), // inputs[41]
        forestMerkleRoot: await getSnarkFriendlyBytes(), // inputs[42]
        saltHash: await getSnarkFriendlyBytes(), // inputs[43]
        magicalConstraint: await getSnarkFriendlyBytes(), // inputs[44]
    };
}

export const sampleProof: SnarkProofStruct = {
    a: {x: getSnarkFriendlyBytes(), y: getSnarkFriendlyBytes()},
    b: {
        x: [getSnarkFriendlyBytes(), getSnarkFriendlyBytes()],
        y: [getSnarkFriendlyBytes(), getSnarkFriendlyBytes()],
    },
    c: {x: getSnarkFriendlyBytes(), y: getSnarkFriendlyBytes()},
};

export function generateExtraInputsHash(
    types: string[],
    values: string[],
): string {
    const extraInput = ethers.utils.solidityPack(types, values);

    const hash = ethers.BigNumber.from(
        ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
    )
        .mod(SNARK_FIELD_SIZE)
        .toString();

    return hash;
}
