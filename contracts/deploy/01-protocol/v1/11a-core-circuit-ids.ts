// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {GAS_PRICE} from './parameters';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const {
        deployments: {get},
        ethers,
    } = hre;

    const {abi} = await get('AppConfiguration');
    const {address} = await get('PantherPoolV1');
    const diamond = await ethers.getContractAt(abi, address);

    const verificationKeys = JSON.parse(
        process.env.VERIFICATION_KEY_POINTERS as string,
    );

    const txTypes = {
        zAccountRegistration: '0x100',
        zAccountRenewal: '0x102',
        prpAccounting: '0x103',
        prpConversion: '0x104',
        zTransaction: '0x105',
        zSwap: '0x106',
    };

    {
        const txType = txTypes.zAccountRegistration;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'zAccountRegistration',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();
            console.log(
                'zAccount registration vk pointer updated',
                res.transactionHash,
            );
        }
    }

    {
        const txType = txTypes.zAccountRenewal;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'zAccountRenewal',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();

            console.log(
                'zAccount renewal vk pointer updated',
                res.transactionHash,
            );
        }
    }

    {
        const txType = txTypes.prpAccounting;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'prpAccounting',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();

            console.log(
                'prp accounting vk pointer updated',
                res.transactionHash,
            );
        }
    }

    {
        const txType = txTypes.prpConversion;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'prpConversion',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();

            console.log(
                'prp conversion vk pointer updated',
                res.transactionHash,
            );
        }
    }

    {
        const txType = txTypes.zTransaction;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'zTransaction',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();

            console.log('zTransaction vk pointer updated', res.transactionHash);
        }
    }

    {
        const txType = txTypes.zSwap;
        const pointer = verificationKeys.filter(
            (x: any) => x.key === 'zSwap',
        )[0].pointer;

        const circuitId = await diamond.getCircuitIds(txType);

        if (circuitId != BigInt(pointer)) {
            const tx = await diamond.updateCircuitId(txType, pointer, {
                gasPrice: GAS_PRICE,
            });
            const res = await tx.wait();

            console.log('zSwap vk pointer updated', res.transactionHash);
        }
    }
};
export default func;

func.tags = ['core-circuits', 'core', 'protocol-v1'];
func.dependencies = ['verifications-keys', 'add-app-configuration'];
