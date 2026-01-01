// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

// This file contains the parameters for Panther protocol deployed in
// Polygon Mainnet

import {ethers} from 'ethers';

export const GAS_PRICE = 100e9; // Gas price in gwei
export const NATIVE_ADDRESS = ethers.constants.AddressZero; // zero address for native token

// maxBlocktimeOffset: The maximum block time offset value to be
// compared with UTXO create/spend time.
export const maxBlocktimeOffset = '1800'; // 30 mins
// ZKP amount (initially) added to the PRP AMM liquidity
export const zkpAmount = ethers.utils.parseEther('100');
export const prpVirtualAmount = zkpAmount.div(ethers.utils.parseUnits('1', 17));

export const FEE_MASTER = {
    FEE_PARAMS: {
        // Rewards (in ZKP) to miner per UTXO mined
        perUtxoReward: ethers.utils.parseEther('0.5'),
        // Fee (in ZKP) for KYT attestation
        perKytFee: ethers.utils.parseEther('25'),
        // Fee (in ZKP) for KYC attestation
        kycFee: ethers.utils.parseEther('100'),
        // Protocol Fee (%) on withdrawal (0.30%)
        protocolFeePercentage: '30',
    },
    // Treasury percentage of the protocol fees (%)
    treasuryLockPercentage: 50 * 100, // 50%
    // Min rewardable zkp amount for (1) protocol fee split to PRP
    // AMM (fee master) and the treasury (2) swapping protocol fees
    minRewardableZkpAmount: ethers.utils.parseEther('1000'),
    // nativeTokenReserveTarget: a desired native token that feeMaster
    // aims to always have.
    nativeTokenReserveTarget: ethers.utils.parseEther('10'),
    // nativeTokenReserves: the current amount of native token (POL) feeMaster
    nativeTokenReserves: ethers.utils.parseEther('10'),
    // ZKP amount (initially) reserved for donations ( Subsidy Pool)
    zkpTokenReserves: ethers.utils.parseEther('1000'),
    // twap value: to get the native/zkp rate.
    twap: '30',
    // feeMaster::updateDonations, check 07g-update-zkp-donatin.ts
    // Donation amount (in ZKP) for each tx type
    // (account activation, account renewal, voucher claim, PRP conversion,
    // internal transfer, deposit, withdraw, zswap).
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
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('200'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
        ethers.utils.parseEther('0'),
    ],
};

// Trust Provider address to claim fees (EOA)
export const COMPLIANCE_TREASURY = {
    trustProvider: '0x4b869a95472e3b90ff081F8bb645d4Da87be8432',
};

// TODO: not found in spreadsheet
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

// mining tech params
export const FOREST_TREE = {
    reservationRate: '2000',
    premiumRate: '10',
    minEmptyQueueAge: '50',
};

// The Providers keys parameters
export const PROVIDERS_KEY = {
    numAllocKeys: [20, 50],
};

export const ZKP_RESERVE_CONTROLLER = {
    // ZkpReserveController::updateParams(), check
    // 94a-update-zkp-reserve-controller-params.ts
    releasablePerBlock: ethers.utils.parseEther('0.7715972222'),
    minRewardedAmount: ethers.utils.parseEther('100'),
    // this is the amount of tokens that must be transfered
    // to the contract. no function call is needed in the
    // ZKPReserveController. check 94b-transfer-zkp-reserve.ts
    zkpTokenReserves: ethers.utils.parseEther('4000'),
};

export const VOUCHER_TERMS = {
    // PantherPoolV1::updateVoucherTerms,
    // check 99z-add-prp-vouchers.ts. the type name is "Onboarding"
    onboarding: ethers.BigNumber.from(1000),
    // PantherPoolV1.updateVoucherTerms,
    // check 99z-add-prp-vouchers.ts. the type name is "ZkpRelease"
    zkpRelease: ethers.BigNumber.from(50),
    // PantherPoolV1.updateVoucherTerms,
    // check 99z-add-prp-vouchers.ts. the type name is "ZkpDistribute"
    zkpDistribute: ethers.BigNumber.from(50),
    // PantherPoolV1.updateVoucherTerms,
    // check 99z-add-prp-vouchers.ts. the type name is "FeeExchange"
    feeExchange: ethers.BigNumber.from(100),
    // PantherPoolV1.updateVoucherTerms,
    // check 99z-add-prp-vouchers.ts. the type name is "PaymasterRefund"
    paymasterRefund: ethers.BigNumber.from(100),
};

// TODO: not found in spreadsheet
export const PAYMASTER = {
    // POL amount (initially) deposited for the
    // Paymaster with the EntryPoint
    depositValue: ethers.utils.parseEther('10'),
    unstakeDelaySec: 87400,
    addStakeValue: ethers.utils.parseEther('5'),
    maxExtraGas: 500000,
    // gasPriceMarkupPct: 333333333333400,
    gasPriceMarkupPct: 452079556100,
    exchangeRiskPct: 1000,
    depositThreshold: 10,
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
