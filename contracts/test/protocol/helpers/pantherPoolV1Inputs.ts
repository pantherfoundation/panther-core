// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {TokenType} from '../../../lib/token';
import {
    generatePrivateMessage,
    TransactionTypes,
} from '../data/samples/transactionNote.data';
import {getBlockTimestamp} from '../helpers/hardhat';

const examplePubKeys = {
    x: '11422399650618806433286579969134364085104724365992006856880595766565570395421',
    y: '1176938832872885725065086511371600479013703711997288837813773296149367990317',
};

const getSnarkFriendlyBytes = (length = 32) => {
    return ethers.BigNumber.from(ethers.utils.randomBytes(length))
        .mod(SNARK_FIELD_SIZE)
        .toString();
};

export type ForestTreesStruct = {
    taxiTree: string;
    busTree: string;
    ferryTree: string;
};

interface CreateZAccountOptions {
    extraInputsHash?: string;
    addedAmountZkp?: number;
    chargedAmountZkp?: BigNumber;
    zAccountId?: number;
    zAccountCreateTime?: BigNumber;
    zAccountRootSpendPubKeyX?: string;
    zAccountRootSpendPubKeyY?: string;
    zAccountPubReadKeyX?: string;
    zAccountPubReadKeyY?: string;
    zAccountNullifierPubKeyX?: string;
    zAccountNullifierPubKeyY?: string;
    zAccountMasterEOA?: string;
    zAccountNullifierZone?: BigNumber;
    commitment?: string;
    kycSignedMessageHash?: string;
    staticTreeMerkleRoot?: string;
    forestMerkleRoot?: string;
    saltHash?: string;
    magicalConstraint?: string;
}

interface PrpClaimandConversionOptions {
    extraInputsHash?: string;
    addedAmountZkp?: number;
    chargedAmountZkp?: BigNumber;
    utxoOutCreateTime?: BigNumber;
    depositPrpAmount?: BigNumber;
    withdrawPrpAmount?: BigNumber;
    utxoCommitmentPrivatePart?: string;
    utxoSpendPubKeyX?: string;
    utxoSpendPubKeyY?: string;
    zAssetScale?: number;
    zAccountUtxoInNullifier?: string;
    zAccountUtxoOutCommitment?: string;
    zNetworkChainId?: number;
    staticTreeMerkleRoot?: string;
    forestMerkleRoot?: string;
    saltHash?: string;
    magicalConstraint?: string;
}

interface MainOptions {
    extraInputsHash?: BigNumber;
    depositPrpAmount?: BigNumber;
    withdrawPrpAmount?: BigNumber;
    addedAmountZkp?: number;
    token?: string;
    tokenId?: number;
    spendTime?: number;
    zAssetUtxoInNullifier1?: string;
    zAssetUtxoInNullifier2?: string;
    zAccountUtxoInNullifier?: string;
    ZoneDataEscrowEphimeralPubKeyAx?: string;
    zZoneDataEscrowEncryptedMessageAx?: string;
    kytDepositSignedMessageSender?: string;
    kytDepositSignedMessageReceiver?: string;
    kytDepositSignedMessageHash?: string;
    kytWithdrawSignedMessageSender?: string;
    kytWithdrawSignedMessageReceiver?: string;
    kytWithdrawSignedMessageHash?: string;
    dataEscrowEphimeralPubKeyAx?: string;
    dataEscrowEncryptedMessageAx1?: string;
    dataEscrowEncryptedMessageAx2?: string;
    dataEscrowEncryptedMessageAx3?: string;
    dataEscrowEncryptedMessageAx4?: string;
    dataEscrowEncryptedMessageAx5?: string;
    dataEscrowEncryptedMessageAx6?: string;
    dataEscrowEncryptedMessageAx7?: string;
    dataEscrowEncryptedMessageAx8?: string;
    dataEscrowEncryptedMessageAx9?: string;
    daoDataEscrowEphimeralPubKeyAx?: string;
    daoDataEscrowEncryptedMessageAx1?: string;
    zAccountCreateTime?: string;
    zAssetUtxoOutCommitment1?: string;
    zAssetUtxoOutCommitment2?: string;
    zAccountUtxoOutCommitment?: string;
    chargedAmountZkp?: string;
    zNetworkChainId?: number;
    staticTreeMerkleRoot?: string;
    forestMerkleRoot?: string;
    saltHash?: string;
    magicalConstraint?: string;
}

export async function getPrpClaimandConversionInputs(
    options: PrpClaimandConversionOptions,
) {
    const addedAmountZkp = options.addedAmountZkp || 0;
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const privateMessages = generatePrivateMessage(
        TransactionTypes.zAccountActivation,
    );
    const utxoOutCreateTime =
        options.utxoOutCreateTime || (await getBlockTimestamp()) + 10;
    const depositPrpAmount = options.depositPrpAmount || BigNumber.from(0);
    const withdrawPrpAmount = options.withdrawPrpAmount || BigNumber.from(10);
    const utxoSpendPubKeyX = options.utxoSpendPubKeyX || examplePubKeys.x;
    const utxoSpendPubKeyY = options.utxoSpendPubKeyY || examplePubKeys.y;
    const zAssetScale = options.zAssetScale || 100000;
    const zNetworkChainId = options.zNetworkChainId || 31337;
    const zAccountUtxoInNullifier =
        options.zAccountUtxoInNullifier || BigNumber.from(1);
    const zAccountUtxoOutCommitment =
        options.zAccountUtxoOutCommitment ||
        ethers.utils.id('zAccountUtxoOutCommitment');
    const staticTreeMerkleRoot =
        options.staticTreeMerkleRoot || ethers.utils.id('staticTreeMerkleRoot');
    const forestMerkleRoot =
        options.forestMerkleRoot || ethers.utils.id('forestMerkleRoot');
    const saltHash =
        options.saltHash ||
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes('PANTHER_EIP712_DOMAIN_SALT'),
        );
    const magicalConstraint =
        options.magicalConstraint || ethers.utils.id('magicalConstraint');
    const transactionOptions = 0;
    const utxoCommitmentPrivatePart = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const extraInput = ethers.utils.solidityPack(
        ['uint32', 'uint96', 'bytes'],
        [transactionOptions, paymasterCompensation, privateMessages],
    );
    const calculatedExtraInputHash = BigNumber.from(
        ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
    ).mod(SNARK_FIELD_SIZE);

    const extraInputsHash = options.extraInputsHash || calculatedExtraInputHash;

    return [
        extraInputsHash,
        addedAmountZkp,
        chargedAmountZkp,
        utxoOutCreateTime,
        depositPrpAmount,
        withdrawPrpAmount,
        utxoCommitmentPrivatePart,
        utxoSpendPubKeyX,
        utxoSpendPubKeyY,
        zAssetScale,
        zAccountUtxoInNullifier,
        zAccountUtxoOutCommitment,
        zNetworkChainId,
        staticTreeMerkleRoot,
        forestMerkleRoot,
        saltHash,
        magicalConstraint,
    ];
}

export async function getCreateZAccountInputs(options: CreateZAccountOptions) {
    const addedAmountZkp = options.addedAmountZkp || 0;
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const zAccountId = options.zAccountId || 0;
    const privateMessages = generatePrivateMessage(
        TransactionTypes.zAccountActivation,
    );
    const zAccountCreateTime =
        options.zAccountCreateTime || (await getBlockTimestamp()) + 10;
    const zAccountRootSpendPubKeyX =
        options.zAccountRootSpendPubKeyX || examplePubKeys.x;
    const zAccountRootSpendPubKeyY =
        options.zAccountRootSpendPubKeyY || examplePubKeys.y;
    const zAccountPubReadKeyX = options.zAccountPubReadKeyX || examplePubKeys.x;
    const zAccountPubReadKeyY = options.zAccountPubReadKeyY || examplePubKeys.y;
    const zAccountMasterEOA =
        options.zAccountMasterEOA || ethers.constants.AddressZero;
    const zAccountNullifierZone =
        options.zAccountNullifierZone || BigNumber.from(1);
    const zAccountNullifierPubKeyX =
        options.zAccountNullifierPubKeyX || ethers.utils.id('nullifier');
    const zAccountNullifierPubKeyY =
        options.zAccountNullifierPubKeyY || ethers.utils.id('nullifier');
    const commitment = options.commitment || ethers.utils.id('commitment');
    const kycSignedMessageHash =
        options.kycSignedMessageHash || ethers.utils.id('kycSignedMessageHash');
    const staticTreeMerkleRoot =
        options.staticTreeMerkleRoot || ethers.utils.id('staticTreeMerkleRoot');
    const forestMerkleRoot =
        options.forestMerkleRoot || ethers.utils.id('forestMerkleRoot');
    const saltHash =
        options.saltHash ||
        ethers.utils.keccak256(
            ethers.utils.toUtf8Bytes('PANTHER_EIP712_DOMAIN_SALT'),
        );
    const magicalConstraint =
        options.magicalConstraint || ethers.utils.id('magicalConstraint');
    const transactionOptions = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const extraInput = ethers.utils.solidityPack(
        ['uint32', 'uint96', 'bytes'],
        [transactionOptions, paymasterCompensation, privateMessages],
    );
    const calculatedExtraInputHash = BigNumber.from(
        ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
    ).mod(SNARK_FIELD_SIZE);

    const extraInputsHash = options.extraInputsHash || calculatedExtraInputHash;

    return [
        extraInputsHash,
        addedAmountZkp,
        chargedAmountZkp,
        zAccountId,
        zAccountCreateTime,
        zAccountRootSpendPubKeyX,
        zAccountRootSpendPubKeyY,
        zAccountPubReadKeyX,
        zAccountPubReadKeyY,
        zAccountNullifierPubKeyX,
        zAccountNullifierPubKeyY,
        zAccountMasterEOA,
        zAccountNullifierZone,
        commitment,
        kycSignedMessageHash,
        staticTreeMerkleRoot,
        forestMerkleRoot,
        saltHash,
        magicalConstraint,
    ];
}

export async function getMainInputs(options: MainOptions) {
    const privateMessages = generatePrivateMessage(TransactionTypes.main);
    const transactionOptions = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const extraInput = ethers.utils.solidityPack(
        ['uint32', 'uint8', 'uint96', 'bytes'],
        [
            transactionOptions,
            TokenType.Erc20,
            paymasterCompensation,
            privateMessages,
        ],
    );
    const calculatedExtraInputHash = BigNumber.from(
        ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
    ).mod(SNARK_FIELD_SIZE);
    const extraInputsHash = options.extraInputsHash || calculatedExtraInputHash;
    const depositPrpAmount = options.depositPrpAmount || BigNumber.from(0);
    const withdrawPrpAmount = options.withdrawPrpAmount || BigNumber.from(10);
    const addedAmountZkp = options.addedAmountZkp || 0;
    const zAccountCreateTime =
        options.zAccountCreateTime || (await getBlockTimestamp()) + 10;
    const spendTime =
        options.spendTime || ((await getBlockTimestamp()) - 60).toString();
    const zAssetUtxoInNullifier1 =
        options.zAccountUtxoInNullifier || BigNumber.from(1);
    const zAssetUtxoInNullifier2 =
        options.zAccountUtxoInNullifier || BigNumber.from(2);
    const zAccountUtxoInNullifier =
        options.zAccountUtxoInNullifier || BigNumber.from(3);
    const zAccountUtxoOutCommitment =
        options.zAccountUtxoOutCommitment ||
        ethers.utils.id('zAccountUtxoOutCommitment');
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const token = options.token || ethers.Wallet.createRandom().address;
    const tokenId = options.tokenId || 0;
    const zNetworkChainId = options.zNetworkChainId || 31337;
    const ZoneDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const zZoneDataEscrowEncryptedMessageAx = getSnarkFriendlyBytes(); // MAIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND
    const kytDepositSignedMessageSender =
        options.kytDepositSignedMessageSender ||
        ethers.Wallet.createRandom().address; // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_SENDER_IND
    const kytDepositSignedMessageReceiver =
        options.kytDepositSignedMessageReceiver ||
        ethers.Wallet.createRandom().address; // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_RECEIVER_IND
    const kytDepositSignedMessageHash =
        options.kytDepositSignedMessageHash || getSnarkFriendlyBytes(); // MAIN_KYT_DEPOSIT_SIGNED_MESSAGE_HASH_IND
    const kytWithdrawSignedMessageSender =
        options.kytWithdrawSignedMessageSender ||
        ethers.Wallet.createRandom().address; // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_SENDER_IND
    const kytWithdrawSignedMessageReceiver =
        ethers.Wallet.createRandom().address; // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_RECEIVER_IND
    const kytWithdrawSignedMessageHash =
        options.kytWithdrawSignedMessageHash || getSnarkFriendlyBytes(); // MAIN_KYT_WITHDRAW_SIGNED_MESSAGE_HASH_IND
    const dataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const dataEscrowEncryptedMessageAx1 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX0_IND
    const dataEscrowEncryptedMessageAx2 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX1_IND
    const dataEscrowEncryptedMessageAx3 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX2_IND
    const dataEscrowEncryptedMessageAx4 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX3_IND
    const dataEscrowEncryptedMessageAx5 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX4_IND
    const dataEscrowEncryptedMessageAx6 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX5_IND
    const dataEscrowEncryptedMessageAx7 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX6_IND
    const dataEscrowEncryptedMessageAx8 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX7_IND
    const dataEscrowEncryptedMessageAx9 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX8_IND
    const daoDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const daoDataEscrowEncryptedMessageAx1 = getSnarkFriendlyBytes(); // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_1
    const staticTreeMerkleRoot =
        options.staticTreeMerkleRoot || ethers.utils.id('staticTreeMerkleRoot');
    const forestMerkleRoot =
        options.forestMerkleRoot || ethers.utils.id('forestMerkleRoot');
    const saltHash =
        options.saltHash ||
        '0xc0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fec0fe';
    const magicalConstraint =
        options.magicalConstraint || ethers.utils.id('magicalConstraint');

    return [
        extraInputsHash,
        depositPrpAmount,
        withdrawPrpAmount,
        addedAmountZkp,
        token,
        tokenId,
        spendTime,
        zAssetUtxoInNullifier1,
        zAssetUtxoInNullifier2,
        zAccountUtxoInNullifier,
        ZoneDataEscrowEphimeralPubKeyAx,
        zZoneDataEscrowEncryptedMessageAx,
        kytDepositSignedMessageSender,
        kytDepositSignedMessageReceiver,
        kytDepositSignedMessageHash,
        kytWithdrawSignedMessageSender,
        kytWithdrawSignedMessageReceiver,
        kytWithdrawSignedMessageHash,
        dataEscrowEphimeralPubKeyAx,
        dataEscrowEncryptedMessageAx1,
        dataEscrowEncryptedMessageAx2,
        dataEscrowEncryptedMessageAx3,
        dataEscrowEncryptedMessageAx4,
        dataEscrowEncryptedMessageAx5,
        dataEscrowEncryptedMessageAx6,
        dataEscrowEncryptedMessageAx7,
        dataEscrowEncryptedMessageAx8,
        dataEscrowEncryptedMessageAx9,
        daoDataEscrowEphimeralPubKeyAx,
        daoDataEscrowEncryptedMessageAx1,
        zAccountCreateTime,
        zAccountUtxoOutCommitment,
        zAccountUtxoOutCommitment,
        zAccountUtxoOutCommitment,
        chargedAmountZkp,
        zNetworkChainId,
        staticTreeMerkleRoot,
        forestMerkleRoot,
        saltHash,
        magicalConstraint,
    ];
}
