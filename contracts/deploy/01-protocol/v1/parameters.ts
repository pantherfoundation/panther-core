// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';

export const GAS_PRICE = 30000000000; // Gas price in wei
export const NATIVE_ADDRESS = ethers.constants.AddressZero; // zero address for native token

export const maxBlocktimeOffset = '600'; // 10 mins
export const zkpAmount = ethers.utils.parseEther('1000000');
export const prpVirtualAmount = zkpAmount.div(ethers.utils.parseUnits('1', 17));

export const FEE_MASTER = {
    FEE_PARAMS: {
        perUtxoReward: ethers.utils.parseEther('0.1'),
        perKytFee: ethers.utils.parseEther('5'),
        kycFee: ethers.utils.parseEther('25'),
        protocolFeePercentage: '250',
    },
    treasuryLockPercentage: 10 * 100, // 10%
    minRewardableZkpAmount: ethers.utils.parseEther('10'),
    nativeTokenReserveTarget: ethers.utils.parseEther('2'),
    nativeTokenReserves: ethers.utils.parseEther('0.5'),
    zkpTokenReserves: ethers.utils.parseEther('100000'),
    twap: '30',
    txTypes: [
        '0x100',
        '0x103',
        '0x104',
        '0x105',
        '0x115',
        '0x125',
        '0x135',
        '0x106',
    ],
    donateAmounts: [
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
    ],
};

export const ACCOUNT = {
    ADDRESS_ONE: '0x0000000000000000000000000000000000000001',
    BYTES_ONE: '0x00000001',
    zTxnMain: {
        /**
         * @dev The `uint96` field in the Ztransaction 'main' function calldata
         * `main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
         * paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
         */
        payCompOffset: 324,
        selector: ethers.utils
            .id(
                'main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10),
    },
    prpConversion: {
        /**
         * @dev The second `uint96` field in PrpConversion `convert` function calldata
         * `convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)`
         *  paymasterCompensation offset  -> second `uint96` = 4 + 32 + 256 + 32 + 32 = 356 bytes
         */
        payCompOffset: 356,
        selector: ethers.utils
            .id(
                'convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)',
            )
            .slice(0, 10),
    },
    voucherController: {
        /**
         * @dev The `uint96` field in the PrpVoucherController `accountRewards` function calldata
         * `accountRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
         *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
         */
        payCompOffset: 324,
        selector: ethers.utils
            .id(
                'accountRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10),
    },
    zAccountRegistration: {
        /**
         * @dev The `uint96` field in the ZAccountsRegistration `activateZAccount` function calldata
         * `activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
         *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
         */
        payCompOffset: 324,
        selector: ethers.utils
            .id(
                'activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10),
    },
    zSwap: {
        /**
         * @dev The `uint96` field in the ZSwap `swapZAsset` function calldata
         * `swapZAsset(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes,bytes)`
         *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
         */
        payCompOffset: 324,
        selector: ethers.utils
            .id(
                'swapZAsset(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes,bytes)',
            )
            .slice(0, 10),
    },
    zAccountRenewal: {
        /**
         * @dev The `uint96` field in the zAccountRenewal `renewZAccount` function calldata
         * renewZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)
         * paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
         */
        payCompOffset: 324,
        selector: ethers.utils
            .id(
                'renewZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10),
    },
};

export const FOREST_TREE = {
    reservationRate: '2000',
    premiumRate: '10',
    minEmptyQueueAge: '100',
};

export const PROVIDERS_KEY = {
    numAllocKeys: [20, 50],
};

export const ZKP_RESERVE_CONTROLLER = {
    releasablePerBlock: ethers.utils.parseEther('1'),
    minRewardedAmount: ethers.utils.parseEther('500'),
    zkpTokenReserves: ethers.utils.parseEther('1000000'),
};

export const PAYMASTER = {
    depositValue: ethers.utils.parseEther('5'),
    unstakeDelaySec: 87400,
    addStakeValue: ethers.utils.parseEther('5'),
};
