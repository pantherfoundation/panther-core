// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';

export const GAS_PRICE = 450e9; // Gas price in gwei
export const NATIVE_ADDRESS = ethers.constants.AddressZero; // zero address for native token

export const maxBlocktimeOffset = '600'; // 10 mins
export const zkpAmount = ethers.utils.parseEther('300');
export const prpVirtualAmount = zkpAmount.div(ethers.utils.parseUnits('1', 17));

export const FEE_MASTER = {
    FEE_PARAMS: {
        perUtxoReward: ethers.utils.parseEther('0.1'),
        perKytFee: ethers.utils.parseEther('5'),
        kycFee: ethers.utils.parseEther('25'),
        protocolFeePercentage: '250',
    },
    treasuryLockPercentage: 10 * 100, // 10%
    minRewardableZkpAmount: ethers.utils.parseEther('50'),
    nativeTokenReserveTarget: ethers.utils.parseEther('50'),
    nativeTokenReserves: ethers.utils.parseEther('50'),
    zkpTokenReserves: ethers.utils.parseEther('3000'),
    twap: '30',
    txTypes: [
        '0x100',
        '0x101',
        '0x102',
        '0x103',
        '0x104',
        '0x105',
        '0x115',
        '0x125',
        '0x135',
        '0x106',
    ],
    donateAmounts: [
        ethers.utils.parseEther('40'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('60'),
        ethers.utils.parseEther('60'),
        ethers.utils.parseEther('40'),
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
    releasablePerBlock: ethers.utils.parseEther('0.01'),
    minRewardedAmount: ethers.utils.parseEther('100'),
    zkpTokenReserves: ethers.utils.parseEther('3000'),
};

export const PAYMASTER = {
    depositValue: ethers.utils.parseEther('50'),
    unstakeDelaySec: 87400,
    addStakeValue: ethers.utils.parseEther('5'),
    maxExtraGas: 500000,
    // gasPriceMarkupPct: 333333333333400,
    gasPriceMarkupPct: 452079556100,
    exchangeRiskPct: 1000,
    // bundlerAddresses: [
    //     '0x319fe457676941EA433770802c3e5Ac6FFAA401A',
    //     '0x7d53502B713058F7C22EAd5Ff97A88b7c9dec542',
    // ],
    bundlerAddresses: [
        '0xfb925186f787694009ab6404b9caab95bc7ae377',
        '0x175a9777c6cf26e26947210bd8bab324d60dcf3c',
        '0xdcdd0ddeaa0407c26dfcd481de9a34e1c55f8d54',
        '0x9776cab4a2dce3dc96db55c919eee822c40b94ee',
        '0x4e0df48f7584ad9ae9978c60178ef726345cc48a',
        '0x29830065d28765e34c19eb774794f010e7b50cf9',
        '0x7c1c87d06f88786d4da52a0e81f82aea9d90e1ec',
        '0xc360e1da5b9bdb9a8879a0cfa1180556426e2305',
        '0x6baad70fc330c22cf26b51897b84fd3281d283a2',
        '0xc85a109221d6b3593b01b36d5b2b6719d2ab7518',
    ],
};
