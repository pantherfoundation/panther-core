// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {BigNumber} from 'ethers';
import {ethers} from 'hardhat';

import {encodeTokenTypeAndAddress} from '../../../lib/token';
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
    tokenType: number;
    spendTime?: number;
    zAssetUtxoInNullifier1?: string;
    zAssetUtxoInNullifier2?: string;
    zAccountUtxoInNullifier?: BigNumber;
    ZoneDataEscrowEphimeralPubKeyAx?: string;
    zZoneDataEscrowEncryptedMessage?: string;
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

interface SwapOptions {
    extraInputsHash?: BigNumber;
    depositPrpAmount?: BigNumber;
    withdrawPrpAmount?: BigNumber;
    addedAmountZkp?: number;
    existingToken?: string;
    incomingToken?: string;
    existingTokenId?: number;
    incomingTokenId?: number;
    existingTokenType: number;
    incomingTokenType: number;
    existingZassetScale?: BigNumber;
    incomingZassetScale?: BigNumber;
    zzkpScale?: BigNumber;
    spendTime?: string;
    zAccountUtxoInNullifier?: BigNumber;
    zAccountUtxoOutCommitment?: string;
    kytDepositSignedMessageSender?: string;
    kytDepositSignedMessageReceiver?: string;
    kytDepositSignedMessageHash?: string;
    kytWithdrawSignedMessageSender?: string;
    kytWithdrawSignedMessageHash?: string;
    chargedAmountZkp?: BigNumber;
    zNetworkChainId?: number;
    staticTreeMerkleRoot?: string;
    forestMerkleRoot?: string;
    saltHash?: string;
    magicalConstraint?: string;
}

interface zAccountRenewalOptions {
    extraInputsHash?: BigNumber;
    addedAmountZkp?: number;
    chargedAmountZkp?: BigNumber;
    nullifier?: number;
    commitment?: string;
    utxoOutCreateTime?: number;
    kycSignedMessageHash?: string;
    staticTreeMerkleRoot?: string;
    forestMerkleRoot?: string;
    saltHash?: string;
    magicalConstraint?: string;
}

export async function getzAccountRenewalInputs(
    options: zAccountRenewalOptions,
) {
    const addedAmountZkp = options.addedAmountZkp || 0;
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const privateMessages = generatePrivateMessage(
        TransactionTypes.zAccountRenewal,
    );
    const utxoOutCreateTime =
        options.utxoOutCreateTime || (await getBlockTimestamp()) + 10;
    const nullifier = options.nullifier || BigNumber.from(1);
    const commitment = options.commitment || ethers.utils.id('commitment');
    const kycSignedMessageHash =
        options.kycSignedMessageHash || getSnarkFriendlyBytes();
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
    const transactionOptions = 0x102;

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
        nullifier,
        commitment,
        utxoOutCreateTime,
        kycSignedMessageHash,
        staticTreeMerkleRoot,
        forestMerkleRoot,
        saltHash,
        magicalConstraint,
    ];
}

export async function getPrpClaimandConversionInputs(
    options: PrpClaimandConversionOptions,
) {
    const addedAmountZkp = options.addedAmountZkp || 0;
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const privateMessages = generatePrivateMessage(
        TransactionTypes.prpConversion,
    );
    const utxoOutCreateTime =
        options.utxoOutCreateTime || (await getBlockTimestamp()) + 10;
    const depositPrpAmount = options.depositPrpAmount || BigNumber.from(0);
    const withdrawPrpAmount = options.withdrawPrpAmount || BigNumber.from(10);

    const zAssetScale =
        options.zAssetScale || BigNumber.from('100000000000000');
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
    const transactionOptions = 0x104;

    const utxoCommitmentPrivatePart = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const zkpAmountMin = ethers.utils.parseEther('10');
    const extraInput = ethers.utils.solidityPack(
        ['uint32', 'uint96', 'uint96', 'bytes'],
        [
            transactionOptions,
            zkpAmountMin,
            paymasterCompensation,
            privateMessages,
        ],
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
        options.zAccountNullifierPubKeyX || BigNumber.from(2);
    const zAccountNullifierPubKeyY =
        options.zAccountNullifierPubKeyY || BigNumber.from(3);
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
    const transactionOptions = 256;
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
        ['uint32', 'uint96', 'bytes'],
        [transactionOptions, paymasterCompensation, privateMessages],
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
    const token = encodeTokenTypeAndAddress(
        options.tokenType,
        BigNumber.from(options.token),
    );
    const tokenId = options.tokenId || 0;
    const zNetworkChainId = options.zNetworkChainId || 31337;
    const ZoneDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_ZZONE_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const zZoneDataEscrowEncryptedMessage = getSnarkFriendlyBytes(); // MAIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_IND
    const zZoneDataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes(); // MAIN_ZZONE_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND
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
    const kytInternalSignedMessageHash = getSnarkFriendlyBytes(); // MAIN_KYT_INTERNAL_SIGNED_MESSAGE_HASH_IND
    const dataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const dataEscrowEncryptedMessageAx1 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX0_IND
    const dataEscrowEncryptedMessageAx2 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX1_IND
    const dataEscrowEncryptedMessageAx3 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX2_IND
    const dataEscrowEncryptedMessageAx4 = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_AX3_IND

    const dataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes(); // MAIN_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND

    const daoDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes(); // MAIN_DAO_DATA_ESCROW_EPHIMERAL_PUB_KEY_AX_IND
    const daoDataEscrowEncryptedMessageAx1 = getSnarkFriendlyBytes(); // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_AX_IND_1
    const daoDataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes(); // MAIN_DAO_DATA_ESCROW_ENCRYPTED_MESSAGE_HMAC_IND
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
        zZoneDataEscrowEncryptedMessage,
        zZoneDataEscrowEncryptedMessageHmac,
        kytDepositSignedMessageSender,
        kytDepositSignedMessageReceiver,
        kytDepositSignedMessageHash,
        kytWithdrawSignedMessageSender,
        kytWithdrawSignedMessageReceiver,
        kytWithdrawSignedMessageHash,
        kytInternalSignedMessageHash,
        dataEscrowEphimeralPubKeyAx,
        dataEscrowEncryptedMessageAx1,
        dataEscrowEncryptedMessageAx2,
        dataEscrowEncryptedMessageAx3,
        dataEscrowEncryptedMessageAx4,
        dataEscrowEncryptedMessageHmac,
        daoDataEscrowEphimeralPubKeyAx,
        daoDataEscrowEncryptedMessageAx1,
        daoDataEscrowEncryptedMessageHmac,
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

export async function getSwapInputs(options: SwapOptions) {
    const privateMessages = generatePrivateMessage(TransactionTypes.swapZAsset);
    const transactionOptions = 0;
    const paymasterCompensation = ethers.BigNumber.from('10');
    const deadline = 12345678; // example deadline
    const amountOutMinimum = 1000000000; // example minimum amount
    const fee = 3000; // example fee
    const sqrtPriceLimitX96 = ethers.BigNumber.from(
        '79228162514264337593543950336',
    ); // example sqrt price limit

    const swapData = ethers.utils.solidityPack(
        ['address', 'uint32', 'uint96', 'uint24', 'uint160'],
        [
            ethers.Wallet.createRandom().address,
            deadline, //deadline
            amountOutMinimum,
            fee, //fee
            sqrtPriceLimitX96,
        ],
    );

    const extraInput = ethers.utils.solidityPack(
        ['uint32', 'uint8', 'bytes', 'bytes'],
        [transactionOptions, paymasterCompensation, swapData, privateMessages],
    );
    const calculatedExtraInputHash = BigNumber.from(
        ethers.utils.solidityKeccak256(['bytes'], [extraInput]),
    ).mod(SNARK_FIELD_SIZE);

    const extraInputsHash = options.extraInputsHash || calculatedExtraInputHash;
    const depositPrpAmount = options.depositPrpAmount || BigNumber.from(0);
    const withdrawPrpAmount = options.withdrawPrpAmount || BigNumber.from(10);
    const addedAmountZkp = options.addedAmountZkp || 0;
    const spendTime =
        options.spendTime || ((await getBlockTimestamp()) - 60).toString();
    const zAssetUtxoInNullifier1 = BigNumber.from(1);
    const zAssetUtxoInNullifier2 = BigNumber.from(2);
    const zAccountUtxoInNullifier =
        options.zAccountUtxoInNullifier || BigNumber.from(3);
    const zAccountUtxoOutCommitment =
        options.zAccountUtxoOutCommitment ||
        ethers.utils.id('zAccountUtxoOutCommitment');
    const zAccountUtxoOutCommitmentPvrt = getSnarkFriendlyBytes();
    const chargedAmountZkp =
        options.chargedAmountZkp || ethers.utils.parseEther('10');
    const existingToken = encodeTokenTypeAndAddress(
        options.existingTokenType,
        BigNumber.from(options.existingToken),
    );
    const incomingToken = encodeTokenTypeAndAddress(
        options.incomingTokenType,
        BigNumber.from(options.incomingToken),
    );
    options.incomingToken || ethers.Wallet.createRandom().address;
    const existingTokenId = options.existingTokenId || 0;
    const incomingTokenId = options.incomingTokenId || 0;
    const zNetworkChainId = options.zNetworkChainId || 31337;
    const existingZassetScale =
        options.existingZassetScale || ethers.utils.parseUnits('1', 18);
    const incomingZassetScale =
        options.incomingZassetScale || ethers.utils.parseUnits('1', 18);
    const zzkpScale = options.zzkpScale || ethers.utils.parseUnits('1', 18);
    const ZoneDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes();
    const zZoneDataEscrowEncryptedMessage = getSnarkFriendlyBytes();
    const zZoneDataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes();
    const kytDepositSignedMessageSender =
        options.kytDepositSignedMessageSender ||
        ethers.Wallet.createRandom().address;
    const kytDepositSignedMessageReceiver =
        options.kytDepositSignedMessageReceiver ||
        ethers.Wallet.createRandom().address;
    const kytDepositSignedMessageHash =
        options.kytDepositSignedMessageHash || getSnarkFriendlyBytes();
    const kytWithdrawSignedMessageSender =
        options.kytWithdrawSignedMessageSender ||
        ethers.Wallet.createRandom().address;
    const kytWithdrawSignedMessageReceiver =
        ethers.Wallet.createRandom().address;
    const kytWithdrawSignedMessageHash =
        options.kytWithdrawSignedMessageHash || getSnarkFriendlyBytes();
    const kytInternalSignedMessageHash = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageAx1 = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageAx2 = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageAx3 = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageAx4 = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageAx5 = getSnarkFriendlyBytes();
    const dataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes();
    const daoDataEscrowEphimeralPubKeyAx = getSnarkFriendlyBytes();
    const daoDataEscrowEncryptedMessage = getSnarkFriendlyBytes();
    const daoDataEscrowEncryptedMessageHmac = getSnarkFriendlyBytes();
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
        extraInputsHash, //0
        depositPrpAmount, //1
        withdrawPrpAmount, //2
        addedAmountZkp, //3
        existingToken, //4
        incomingToken, //5
        existingTokenId, //6
        incomingTokenId, //7
        existingZassetScale, //8
        incomingZassetScale, //9
        zzkpScale, //10
        spendTime, //11
        zAssetUtxoInNullifier1, //12
        zAssetUtxoInNullifier2, //13
        zAccountUtxoInNullifier, //14
        ZoneDataEscrowEphimeralPubKeyAx, //15
        zZoneDataEscrowEncryptedMessage, //16
        zZoneDataEscrowEncryptedMessageHmac, //17
        kytDepositSignedMessageSender, //18
        kytDepositSignedMessageReceiver, //19
        kytDepositSignedMessageHash, //20
        kytWithdrawSignedMessageSender, //21
        kytWithdrawSignedMessageReceiver, //22
        kytWithdrawSignedMessageHash, //23
        kytInternalSignedMessageHash, //24
        dataEscrowEncryptedMessageAx1, //25
        dataEscrowEncryptedMessageAx2, //26
        dataEscrowEncryptedMessageAx3, //27
        dataEscrowEncryptedMessageAx4, //28
        dataEscrowEncryptedMessageAx5, //29
        dataEscrowEncryptedMessageHmac, //30
        daoDataEscrowEphimeralPubKeyAx, //31
        daoDataEscrowEncryptedMessage, //32
        daoDataEscrowEncryptedMessageHmac, //33
        (await getBlockTimestamp()) + 10, //34 // Assuming zAccountCreateTime is calculated like this
        zAccountUtxoOutCommitment, //35
        zAccountUtxoOutCommitmentPvrt, //36
        zAccountUtxoOutCommitment, //37
        chargedAmountZkp, //38
        zNetworkChainId, //39
        staticTreeMerkleRoot, //40
        forestMerkleRoot, //41
        saltHash, //42
        magicalConstraint, //43
    ];
}
