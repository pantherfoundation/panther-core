// SPDX-License-Identifier: MIT
// import {SignerWithAddress} from '@nomiclabs/hardhat-ethers/signers';
// import {expect} from 'chai';
// import {BigNumber} from 'ethers';
// import {ethers} from 'hardhat';
//
// import {
//     getPoseidonT3Contract,
//     getPoseidonT4Contract,
// } from './../../lib/poseidonBuilder';
//
// import {TrustProvidersKeys} from '../../types/contracts';
//
// import {revertSnapshot, takeSnapshot} from './helpers/hardhat';
// import {log} from 'console';
//
// describe.skip('TrustProvidersKeys contract', function () {
//     this.timeout('100000000000');
//     let trustProvidersKeys: TrustProvidersKeys;
//     let owner, notOwner, trustProvider: SignerWithAddress;
//
//     before(async () => {
//         [owner, notOwner, trustProvider] = await ethers.getSigners();
//
//         const PoseidonT3 = await getPoseidonT3Contract();
//         const poseidonT3 = await PoseidonT3.deploy();
//         await poseidonT3.deployed();
//
//         const PoseidonT4 = await getPoseidonT4Contract();
//         const poseidonT4 = await PoseidonT4.deploy();
//         await poseidonT4.deployed();
//
//         const TrustProvidersKeys = await ethers.getContractFactory(
//             'TrustProvidersKeys',
//             {
//                 libraries: {
//                     PoseidonT3: poseidonT3.address,
//                     PoseidonT4: poseidonT4.address,
//                 },
//             },
//         );
//         trustProvidersKeys = (await TrustProvidersKeys.deploy(
//             owner.address,
//         )) as TrustProvidersKeys;
//     });
//
//     describe.only('it should add trust provider', () => {
//         it('add', async () => {
//             await trustProvidersKeys.addTrustProvider(
//                 trustProvider.address,
//                 10,
//             );
//
//             const pubKeyX =
//                 11080936704158169907388247709618202787588435494567494349197681020512684291259n;
//             const pubKeyY =
//                 7670441255338842285292946035060060882122193962389759953289000086122973499902n;
//
//             const expiryDate =
//                 (await ethers.provider.getBlock('latest')).timestamp + 86400;
//
//             await expect(
//                 trustProvidersKeys
//                     .connect(trustProvider)
//                     .insertPubKey(pubKeyX, pubKeyY, expiryDate),
//             )
//                 .to.emit(trustProvidersKeys, 'PubKeyInserted')
//                 .withArgs(trustProvider.address, 0, pubKeyX, pubKeyY);
//
//             await expect(
//                 trustProvidersKeys
//                     .connect(trustProvider)
//                     .insertPubKey(pubKeyX, pubKeyY, expiryDate),
//             )
//                 .to.emit(trustProvidersKeys, 'PubKeyInserted')
//                 .withArgs(trustProvider.address, 1, pubKeyX, pubKeyY);
//
//             const tp = await trustProvidersKeys.getTrustProviderOrRevert(
//                 trustProvider.address,
//             );
//
//             console.log(tp.usedLeaves);
//         });
//     });
// });
