// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

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
        daoDataEscrowEncryptedMessageAx1: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_1
        daoDataEscrowEncryptedMessageAx2: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_2
        daoDataEscrowEncryptedMessageAx3: getSnarkFriendlyBytes(), // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_3
        utxoOutCreateTime: ((await getBlockTimestamp()) + 60).toString(), // MAIN_UTXO_OUT_CREATE_TIME_IND
        zAssetUtxoOutCommitment1: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_OUT_COMMITMENT_1_IND
        zAssetUtxoOutCommitment2: getSnarkFriendlyBytes(), // MAIN_ZASSET_UTXO_OUT_COMMITMENT_2_IND
        zAccountUtxoOutCommitment: getSnarkFriendlyBytes(), // MAIN_ZACCOUNT_UTXO_OUT_COMMITMENT_IND
        chargedAmountZkp: ethers.utils.parseEther('1'), // MAIN_CHARGED_AMOUNT_ZKP_IND
        zNetworkChainId: chainId, // MAIN_ZNETWORK_CHAIN_ID_IND
        staticMerkleRoot: ethers.BigNumber.from(0).toString(), // MAIN_STATIC_MERKLE_ROOT_IND
        forestMerkleRoot: getSnarkFriendlyBytes(), // MAIN_FOREST_MERKLE_ROOT_IND
        saltHash: getSnarkFriendlyBytes(), // MAIN_SALT_HASH_IND
        magicalConstraint: getSnarkFriendlyBytes(), // MAIN_MAGICAL_CONSTRAINT_IND
    };
};

export const generateExecPluginTestInputs = async () => {
    const getBlockTimestamp = async () => {
        // Mock or actual implementation to fetch the current block timestamp
        return Math.floor(Date.now() / 1000);
    };

    const chainId = (await ethers.provider.getNetwork()).chainId;

    return {
        extraInputsHash: await getSnarkFriendlyBytes(), // inputs[0] - extraInputsHash
        depositAmount: ethers.utils.parseEther('1000'), // inputs[1] - depositAmount
        withdrawAmount: '0', // inputs[2] - withdrawAmount
        donatedAmountZkp: '0', // inputs[3] - donatedAmountZkp
        tokenIn: ethers.Wallet.createRandom().address, // inputs[4] - tokenIn
        tokenOut: ethers.Wallet.createRandom().address, // inputs[5] - tokenOut
        tokenInId: '0', // inputs[6] - tokenInId
        tokenOutId: '0', // inputs[7] - tokenOutId
        spendTime: ((await getBlockTimestamp()) - 60).toString(), // inputs[8] - spendTime
        utxoInNullifier1: await getSnarkFriendlyBytes(), // inputs[9] - utxoInNullifier1
        utxoInNullifier2: await getSnarkFriendlyBytes(), // inputs[10] - utxoInNullifier2
        zAccountUtxoInNullifier: await getSnarkFriendlyBytes(), // inputs[11] - zAccountUtxoInNullifier
        zZoneDataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[12] - zZoneDataEscrowEphimeralPubKeyAx
        zZoneDataEscrowEncryptedMessageAx: await getSnarkFriendlyBytes(), // inputs[13] - zZoneDataEscrowEncryptedMessageAx
        kytDepositSignedMessageSender: await getSnarkFriendlyBytes(), // inputs[14] - kytDepositSignedMessageSender
        kytDepositSignedMessageReceiver: await getSnarkFriendlyBytes(), // inputs[15] - kytDepositSignedMessageReceiver
        kytDepositSignedMessageHash: await getSnarkFriendlyBytes(), // inputs[16] - kytDepositSignedMessageHash
        kytWithdrawSignedMessageSender: await getSnarkFriendlyBytes(), // inputs[17] - kytWithdrawSignedMessageSender
        kytWithdrawSignedMessageReceiver: await getSnarkFriendlyBytes(), // inputs[18] - kytWithdrawSignedMessageReceiver
        kytWithdrawSignedMessageHash: await getSnarkFriendlyBytes(), // inputs[19] - kytWithdrawSignedMessageHash
        dataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[20] - dataEscrowEphimeralPubKeyAx
        dataEscrowEncryptedMessageAx: await getSnarkFriendlyBytes(), // inputs[21] - dataEscrowEncryptedMessageAx
        daoDataEscrowEphimeralPubKeyAx: await getSnarkFriendlyBytes(), // inputs[22] - daoDataEscrowEphimeralPubKeyAx
        daoDataEscrowEncryptedMessageAx: await getSnarkFriendlyBytes(), // inputs[23] - daoDataEscrowEncryptedMessageAx
        utxoOutCreateTime: ((await getBlockTimestamp()) + 60).toString(), // inputs[24] - utxoOutCreateTime
        utxoOutCommitment1: await getSnarkFriendlyBytes(), // inputs[25] - utxoOutCommitment1
        utxoOutCommitment2: await getSnarkFriendlyBytes(), // inputs[26] - utxoOutCommitment2
        zAccountUtxoOutCommitment: await getSnarkFriendlyBytes(), // inputs[27] - zAccountUtxoOutCommitment
        chargedAmountZkp: ethers.utils.parseEther('1'), // inputs[28] - chargedAmountZkp
        zNetworkChainId: chainId, // inputs[29] - zNetworkChainId
        forestMerkleRoot: await getSnarkFriendlyBytes(), // inputs[30] - forestMerkleRoot
        saltHash: await getSnarkFriendlyBytes(), // inputs[31] - saltHash
        magicalConstraint: await getSnarkFriendlyBytes(), // inputs[32] - magicalConstraint
    };
};

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
