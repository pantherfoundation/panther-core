// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {utils} from 'ethers';

export enum TransactionTypes {
    zAccountActivation = '1',
    prpClaim = '2',
    prpConversion = '3',
    main = '4',
}

enum UtxoMessageTypes {
    zAccount = '06',
    zAssetPrivate = '07',
    zAsset = '08',
    spent2Utxos = '09',
    invalid = '99',
}

enum RevertMessages {
    invalidMtZAccount = 'TN:E1',
    invalidMtZAsset = 'TN:E2',
    invalidMtZAssetPriv = 'TN:E3',
    invalidMtSpend2Utxo = 'TN:E4',
}

const randomEphemeralKey = utils.hexlify(utils.randomBytes(32)).substring(2);
const randomCypherText = utils.hexlify(utils.randomBytes(64)).substring(2);

// Valid message for each type:

const zAccountMessage =
    UtxoMessageTypes.zAccount + randomEphemeralKey + randomCypherText;

const zAssetPrivateMessage =
    UtxoMessageTypes.zAssetPrivate + randomEphemeralKey + randomCypherText;

const zAssetMessage =
    UtxoMessageTypes.zAsset + randomEphemeralKey + randomCypherText;

const spend2UtxoMessage = UtxoMessageTypes.spent2Utxos + randomCypherText;

const invalidMessage = UtxoMessageTypes.invalid + '00';

export function generatePrivateMessage(txType: TransactionTypes): string {
    let privateMessage = '0x';

    if (txType === TransactionTypes.zAccountActivation)
        privateMessage += zAccountMessage;

    if (txType === TransactionTypes.prpClaim) privateMessage += zAccountMessage;

    if (txType === TransactionTypes.prpConversion)
        privateMessage += zAccountMessage + zAssetPrivateMessage;

    if (txType === TransactionTypes.main)
        privateMessage +=
            zAccountMessage + zAssetMessage + zAssetMessage + spend2UtxoMessage;

    return privateMessage;
}

export function generateLowLengthPrivateMessage(
    txType: TransactionTypes,
): string {
    return generatePrivateMessage(txType).slice(0, -2);
}

export function generateInvalidPrivateMessagesAndGetRevertMessages(
    txType: TransactionTypes,
): {privateMessages: string[]; revertMessages: string[]} {
    const privateMessages: string[] = [];
    const revertMessages: string[] = [];

    if (txType === TransactionTypes.zAccountActivation) {
        privateMessages[0] = '0x' + invalidMessage; // should be zAccount type
        revertMessages[0] = RevertMessages.invalidMtZAccount;

        privateMessages[1] = '0x' + zAssetPrivateMessage; // should be zAccount type
        revertMessages[1] = RevertMessages.invalidMtZAccount;
    }

    if (txType === TransactionTypes.prpClaim) {
        privateMessages[0] = '0x' + invalidMessage; // should be zAccount type
        revertMessages[0] = RevertMessages.invalidMtZAccount;

        privateMessages[1] = '0x' + spend2UtxoMessage; // should be zAccount type
        revertMessages[1] = RevertMessages.invalidMtZAccount;
    }

    if (txType === TransactionTypes.prpConversion) {
        privateMessages[0] =
            '0x' +
            zAssetPrivateMessage + // should be zAccount type
            zAccountMessage;
        revertMessages[0] = RevertMessages.invalidMtZAccount;

        privateMessages[1] = '0x' + zAccountMessage + zAssetMessage; // should be zAssetPriv type
        revertMessages[1] = RevertMessages.invalidMtZAssetPriv;

        privateMessages[2] = '0x' + zAccountMessage + zAccountMessage; // should be zAssetPriv type
        revertMessages[2] = RevertMessages.invalidMtZAssetPriv;
    }

    if (txType === TransactionTypes.main) {
        // zAccountMessage + zAssetMessage + zAssetMessage + spend2UtxoMessage
        privateMessages[0] =
            '0x' +
            spend2UtxoMessage + // should be zAccount type
            zAssetMessage +
            zAssetMessage +
            zAccountMessage;
        revertMessages[0] = RevertMessages.invalidMtZAccount;

        privateMessages[1] =
            '0x' +
            zAccountMessage +
            zAccountMessage + // should be zAsset type
            zAssetMessage +
            spend2UtxoMessage;
        revertMessages[1] = RevertMessages.invalidMtZAsset;

        privateMessages[2] =
            '0x' +
            zAccountMessage +
            zAssetMessage +
            zAccountMessage + // should be zAsset type
            spend2UtxoMessage;
        revertMessages[2] = RevertMessages.invalidMtZAsset;

        privateMessages[3] =
            '0x' +
            zAccountMessage +
            zAssetMessage +
            zAssetMessage +
            zAssetMessage; // should be spend2Utxo type
        revertMessages[3] = RevertMessages.invalidMtSpend2Utxo;
    }

    return {privateMessages, revertMessages};
}
