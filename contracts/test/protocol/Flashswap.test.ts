// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
import {expect} from 'chai';
import {ethers, artifacts} from 'hardhat';

import {impersonate, ensureMinBalance} from '../../lib/hardhat';
import {MockProtocolFeeSwapper, IERC20} from '../../types/contracts';

import {getBlockTimestamp} from './helpers/hardhat';

describe.skip('Test FlashSwap in Mainnet', function () {
    let protocolFeeSwapper: MockProtocolFeeSwapper;
    let owner: SignerWithAddress;

    const usdc = '0x2791bca1f2de4661ed88a30c99a7a9449aa84174';
    const zkp = '0x9a06db14d639796b25a6cec6a1bf614fd98815ec';
    const wmatic = '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270';
    const wmatic_zkp_pool = '0x97957C4c96e8A2DB27Bf4f1DE565FF6b7096E028';
    const wmatic_usdc_pool = '0x88f3C15523544835fF6c738DDb30995339AD57d6';
    const random_user = '0x3A3BD7bb9528E159577F7C2e685CC81A765002E2'; //has usdc balance

    // Test cases are executed in polygon forked network at blockNumber 60654816

    before(async function () {
        [owner] = await ethers.getSigners();

        const timestamp = await getBlockTimestamp();
        console.log({timestamp});

        const ProtocolFeeSwapper = await ethers.getContractFactory(
            'MockProtocolFeeSwapper',
        );
        protocolFeeSwapper = (await ProtocolFeeSwapper.connect(owner).deploy(
            wmatic,
        )) as MockProtocolFeeSwapper;
    });

    it('add pool', async () => {
        await protocolFeeSwapper.addPool(
            wmatic_usdc_pool,
            ethers.constants.AddressZero,
            usdc,
        );
        await expect(
            protocolFeeSwapper.addPool(
                wmatic_zkp_pool,
                ethers.constants.AddressZero,
                zkp,
            ),
        ).to.emit(protocolFeeSwapper, 'PoolUpdated');
    });

    it('update twap period', async () => {
        await protocolFeeSwapper.updateTwapPeriod(30);
        const updatedTwap = await protocolFeeSwapper.twapPeriod();

        expect(updatedTwap).to.be.eq(30);
    });

    describe('Execute flashswap', function () {
        let usdc_token_contract: IERC20;
        let wmatic_contract: IERC20;
        let zkp_token_contract: IERC20;
        const swapAmount = 20000000;

        before(async function () {
            const {abi} = await artifacts.readArtifact('ERC20');
            usdc_token_contract = await ethers.getContractAt(abi, usdc);
            wmatic_contract = await ethers.getContractAt(abi, wmatic);
            zkp_token_contract = await ethers.getContractAt(abi, zkp);

            const signer = await impersonate(random_user);
            await ensureMinBalance(
                signer.address,
                ethers.utils.parseEther('10'),
            );

            await usdc_token_contract
                .connect(signer)
                .transfer(protocolFeeSwapper.address, swapAmount);
        });

        it('it should convert usdc to native', async () => {
            const usdc_balance = await usdc_token_contract.balanceOf(
                protocolFeeSwapper.address,
            );

            console.log('protocolFeeSwapper USDC balance', usdc_balance);

            await protocolFeeSwapper.trySwapProtoclFeesToNativeAndZkp(
                zkp,
                usdc,
                swapAmount,
                0,
                ethers.utils.parseEther('1'),
            );

            expect(
                await usdc_token_contract.balanceOf(protocolFeeSwapper.address),
            ).to.be.equal(0);

            expect(
                await ethers.provider.getBalance(protocolFeeSwapper.address),
            ).to.be.greaterThan(0); // 49382539779617319

            expect(
                await wmatic_contract.balanceOf(protocolFeeSwapper.address),
            ).to.be.equal(0);
        });

        it.skip('it should convert usdc to native and excess token to zkp', async () => {
            const usdc_balance = await usdc_token_contract.balanceOf(
                protocolFeeSwapper.address,
            );

            await protocolFeeSwapper.trySwapProtoclFeesToNativeAndZkp(
                zkp,
                usdc,
                20000,
                0,
                1000000000, // less value for nativeTokenReservesTarget
            );

            await expect(
                await usdc_token_contract.balanceOf(protocolFeeSwapper.address),
            ).to.be.equal(usdc_balance.sub(20000));
            await expect(
                await wmatic_contract.balanceOf(protocolFeeSwapper.address),
            ).to.be.equal(0);
            await expect(
                await ethers.provider.getBalance(protocolFeeSwapper.address),
            ).to.be.equal(1000000000); // eth balance is equal to nativeTokenReservesTarget
            await expect(
                await zkp_token_contract.balanceOf(protocolFeeSwapper.address),
            ).to.be.greaterThan(ethers.utils.parseEther('1')); // zkp balance
        });
    });
});
