// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

import {getNamedAccount} from '../../../lib/deploymentHelpers';

const ADDRESS_ONE = '0x0000000000000000000000000000000000000001';
const BYTES_ONE = '0x00000001';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const deployer = await getNamedAccount(hre, 'deployer');

    const {
        deployments: {deploy, get},
        ethers,
    } = hre;

    const coreDiamond = (await get('PantherPoolV1')).address;

    /**
     * @dev The `uint96` field in the Ztransaction 'main' function calldata
     * `main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
     * paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
     */
    const zTxnMainPayCompOffset = 324;
    const zTxnMainSelector = ethers.utils
        .id(
            'main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
        )
        .slice(0, 10);

    /**
     * @dev The second `uint96` field in PrpConversion `convert` function calldata
     * `convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)`
     *  paymasterCompensation offset  -> second `uint96` = 4 + 32 + 256 + 32 + 32 = 356 bytes
     */
    const prpConvPayCompOffset = 356;
    const prpConvSelector = ethers.utils
        .id(
            'convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)',
        )
        .slice(0, 10);

    /**
     * @dev The `uint96` field in the PrpVoucherController `accountRewards` function calldata
     * `accountRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
     *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
     */
    const voucherCtrlAccRwdsPayCompOffset = 324;
    const voucherCtrlAccRwdsSelector = ethers.utils
        .id(
            'accountRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
        )
        .slice(0, 10);

    /**
     * @dev The `uint96` field in the ZAccountsRegistration `activateZAccount` function calldata
     * `activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)`
     *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
     */
    const zAcctRegActivatePayCompOffset = 324;
    const zAcctRegActivateSelector = ethers.utils
        .id(
            'activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
        )
        .slice(0, 10);

    /**
     * @dev The `uint96` field in the ZSwap `swapZAsset` function calldata
     * `swapZAsset(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes,bytes)`
     *  paymasterCompensation offset  -> `uint96` = 4 + 32 + 256 + 32 = 324 bytes
     */
    const zSwapZassetPayCompOffset = 324;
    const zSwapZassetSelector = ethers.utils
        .id(
            'swapZAsset(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes,bytes)',
        )
        .slice(0, 10);

    await deploy('Account', {
        from: deployer,
        args: [
            [
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                coreDiamond,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
            ],
            [
                zTxnMainSelector,
                prpConvSelector,
                voucherCtrlAccRwdsSelector,
                zAcctRegActivateSelector,
                zSwapZassetSelector,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
            ],
            [
                zTxnMainPayCompOffset,
                prpConvPayCompOffset,
                voucherCtrlAccRwdsPayCompOffset,
                zAcctRegActivatePayCompOffset,
                zSwapZassetPayCompOffset,
                0,
                0,
                0,
            ],
        ],
        log: true,
        autoMine: true,
        gasPrice: 30000000000,
    });
};
export default func;

func.tags = ['account'];
func.dependencies = ['core-diamond'];
