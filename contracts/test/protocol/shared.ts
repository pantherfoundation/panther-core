// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {FakeContract, smock} from '@defi-wonderland/smock';
import {JsonRpcSigner} from '@ethersproject/providers/src.ts/json-rpc-provider';
import {UserOperationStruct} from '@panther-core/dapp/src/types/contracts/EntryPoint';
import {SaltedLockDataStruct} from '@panther-core/dapp/src/types/contracts/Vault';
import {BigNumber, Contract, Wallet} from 'ethers';
import {parseEther} from 'ethers/lib/utils';
import hre, {ethers} from 'hardhat';

import {composeExecData} from '../../lib/composeExecData';
import {
    deployContentDeterministically,
    setDeterministicDeploymentProxy,
} from '../../lib/deploymentHelpers';
import {
    getPoseidonT3Contract,
    getPoseidonT4Contract,
    getPoseidonT5Contract,
    getPoseidonT6Contract,
} from '../../lib/poseidonBuilder';
import {
    TokenMock,
    TokenMock__factory,
    PantherStaticTree,
    ZAssetsRegistryV1,
    MockERC20,
    PantherFerryTree,
    ProvidersKeys,
    ZNetworksRegistry,
    PantherTaxiTree,
    PrpVoucherGrantor,
    VaultV1,
    PrpConverter,
    EntryPoint,
    PayMaster,
    Account,
} from '../../types/contracts';

import {
    depositInputs,
    generateExtraInputsHash,
    sampleProof,
} from './data/samples/pantherPool.data';

export const ADDRESS_ZERO = '0x0000000000000000000000000000000000000000';
export const ADDRESS_ONE = '0x0000000000000000000000000000000000000001';
export const BYTES_ONE = '0x00000001';
export const BYTES32_ZERO =
    '0x0000000000000000000000000000000000000000000000000000000000000000';

export const BYTES64_ZERO =
    '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

export function getEncodedProof() {
    return [
        [
            ethers.BigNumber.from(sampleProof.a.x),
            ethers.BigNumber.from(sampleProof.a.y),
        ],
        [
            [
                ethers.BigNumber.from(sampleProof.b.x[0]),
                ethers.BigNumber.from(sampleProof.b.x[1]),
            ],
            [
                ethers.BigNumber.from(sampleProof.b.y[0]),
                ethers.BigNumber.from(sampleProof.b.y[1]),
            ],
        ],
        [
            ethers.BigNumber.from(sampleProof.c.x),
            ethers.BigNumber.from(sampleProof.c.y),
        ],
    ];
}

function encodeVerifyingKeyStruct(vk: VerifyingKeyStruct): string {
    const {alfa1, beta2, gamma2, delta2, ic} = vk;

    return ethers.utils.defaultAbiCoder.encode(
        [
            'tuple(tuple(uint256 x, uint256 y), tuple(uint256[2] x, uint256[2] y), tuple(uint256[2] x, uint256[2] y), tuple(uint256[2] x, uint256[2] y), tuple(uint256 x, uint256 y)[])',
        ],
        [[alfa1, beta2, gamma2, delta2, ic]],
    );
}

const mockVerifyingKey: VerifyingKeyStruct = {
    alfa1: {x: BigNumber.from(1), y: BigNumber.from(2)},
    beta2: {
        x: [BigNumber.from(3), BigNumber.from(4)],
        y: [BigNumber.from(5), BigNumber.from(6)],
    },
    gamma2: {
        x: [BigNumber.from(7), BigNumber.from(8)],
        y: [BigNumber.from(9), BigNumber.from(10)],
    },
    delta2: {
        x: [BigNumber.from(11), BigNumber.from(12)],
        y: [BigNumber.from(13), BigNumber.from(14)],
    },
    ic: [
        {x: BigNumber.from(15), y: BigNumber.from(16)},
        {x: BigNumber.from(17), y: BigNumber.from(18)},
        {x: BigNumber.from(19), y: BigNumber.from(20)},
    ],
};

export class PluginFixture {
    public ethersSigner!: JsonRpcSigner;
    public bundler!: JsonRpcSigner;
    public pantherStaticTreeProxy!: PantherStaticTree;
    public pantherPoolV1Proxy!: Contract;
    public zAssetsRegistryV1!: ZAssetsRegistryV1;
    public testAmount!: BigNumber;
    public pantherVerifier!: PantherVerifier;
    public pantherBusTree: FakeContract<PantherBusTree>;
    public pantherFerryTree!: PantherFerryTree;

    public zNetworksRegistry!: ZNetworksRegistry;
    public providersKeys!: ProvidersKeys;

    public pantherTaxiTree!: PantherTaxiTree;

    public pantherPoolV1Impl!: MockPantherPoolV1;

    public prpVoucherGrantor!: PrpVoucherGrantor;

    public cirquitId!: string;
    public vault!: VaultV1;

    public paymaster!: PayMaster;
    public pantherPool!: MockPantherPoolV1;

    public encodedVerificationKey!: string;
    public erc20Token!: TokenMock;
    public zkpToken!: MockERC20;
    public beneficiaryAddress!: string;

    public accountOwner!: Wallet;

    public dummyWallet!: Wallet;

    public deployer!: {deployerCode: string; deployerAddr: string};

    public entryPoint!: EntryPoint;

    public paymasterProxy!: Contract;

    public smartAccount!: Account;

    public PAYMASTER_VOUCHER_TYPE_ID: string;

    public prpConverter!: PrpConverter;
    public broker: MockFeeMaster;

    public pantherStaticTree: FakeContract<PantherStaticTree>;

    async initFixture() {
        [this.ethersSigner, this.bundler] = await hre.ethers.getSigners();

        let counter = 0;

        const privateKey = ethers.utils.keccak256(
            Buffer.from(ethers.utils.arrayify(BigNumber.from(++counter))),
        );

        const privateKeyForDummyWallet = ethers.utils.keccak256(
            Buffer.from(ethers.utils.arrayify(BigNumber.from(++counter))),
        );

        const beneficiaryPKey = ethers.utils.keccak256(
            Buffer.from(ethers.utils.arrayify(BigNumber.from(++counter))),
        );

        const ben = new ethers.Wallet(beneficiaryPKey, ethers.provider);

        this.beneficiaryAddress = ben.address;

        this.accountOwner = new ethers.Wallet(privateKey, ethers.provider);

        this.dummyWallet = new ethers.Wallet(
            privateKeyForDummyWallet,
            ethers.provider,
        );

        this.erc20Token = await new TokenMock__factory(
            this.ethersSigner,
        ).deploy();

        await setDeterministicDeploymentProxy(hre);

        const {pointer} = await deployContentDeterministically(
            hre,
            encodeVerifyingKeyStruct(mockVerifyingKey),
        );

        this.cirquitId = pointer;

        this.pantherVerifier = await smock.fake('PantherVerifier');

        this.pantherVerifier.verify.returns(true);

        const deployerAddress = await this.ethersSigner.getAddress();

        const EIP173Proxy = await ethers.getContractFactory('EIP173Proxy');

        const vaultProxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero, // implementation will be changed
            deployerAddress,
            [],
        );

        const EIP173ProxyWithReceive = await ethers.getContractFactory(
            'EIP173ProxyWithReceive',
        );

        this.paymasterProxy = await EIP173ProxyWithReceive.deploy(
            ethers.constants.AddressZero, // implementation will be changed
            deployerAddress,
            [],
        );

        this.paymasterProxy.deployed();

        this.pantherStaticTreeProxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero, // implementation will be changed
            deployerAddress,
            [],
        );

        this.pantherPoolV1Proxy = await EIP173Proxy.deploy(
            ethers.constants.AddressZero, // implementation will be changed
            deployerAddress,
            [],
        );
        await this.pantherPoolV1Proxy.deployed();

        const MockERC20 = await ethers.getContractFactory('MockERC20');
        this.zkpToken = await MockERC20.deploy(0, deployerAddress);

        const PoseidonT3 = await getPoseidonT3Contract();
        const poseidonT3 = await PoseidonT3.deploy();
        await poseidonT3.deployed();

        const PoseidonT4 = await getPoseidonT4Contract();
        const poseidonT4 = await PoseidonT4.deploy();
        await poseidonT4.deployed();

        const PoseidonT5 = await getPoseidonT5Contract();
        const poseidonT5 = await PoseidonT5.deploy();
        await poseidonT5.deployed();

        const PoseidonT6 = await getPoseidonT6Contract();
        const poseidonT6 = await PoseidonT6.deploy();
        await poseidonT6.deployed();

        const ZAssetsRegistryV1 = await ethers.getContractFactory(
            'ZAssetsRegistryV1',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        this.zAssetsRegistryV1 = await ZAssetsRegistryV1.deploy(
            deployerAddress,
            this.pantherStaticTreeProxy.address,
        );

        this.pantherBusTree = await smock.fake('PantherBusTree');

        const PantherFerryTree =
            await ethers.getContractFactory('PantherFerryTree');
        this.pantherFerryTree = await PantherFerryTree.deploy();

        const ProvidersKeys = await ethers.getContractFactory('ProvidersKeys', {
            libraries: {
                PoseidonT3: poseidonT3.address,
                PoseidonT4: poseidonT4.address,
            },
        });

        this.providersKeys = await ProvidersKeys.deploy(
            deployerAddress,
            1,
            this.pantherStaticTreeProxy.address,
        );

        await this.providersKeys.deployed();

        const ZNetworksRegistry = await ethers.getContractFactory(
            'ZNetworksRegistry',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );
        this.zNetworksRegistry = await ZNetworksRegistry.deploy(
            deployerAddress,
            this.pantherStaticTreeProxy.address,
        );
        await this.zNetworksRegistry.deployed();

        const PantherTaxiTree = await ethers.getContractFactory(
            'PantherTaxiTree',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                },
            },
        );

        this.pantherTaxiTree = await PantherTaxiTree.deploy(
            this.pantherPoolV1Proxy.address,
        );

        await this.pantherTaxiTree.deployed();

        const PrpVoucherGrantor =
            await ethers.getContractFactory('PrpVoucherGrantor');
        this.prpVoucherGrantor = await PrpVoucherGrantor.deploy(
            deployerAddress,
            this.pantherPoolV1Proxy.address,
        );

        const MockPantherPoolV1 = await ethers.getContractFactory(
            'MockPantherPoolV1',
            {
                libraries: {
                    PoseidonT3: poseidonT3.address,
                    PoseidonT4: poseidonT4.address,
                },
            },
        );

        this.broker = await (
            await ethers.getContractFactory('MockFeeMaster')
        ).deploy('0x0000000000000000000000000000000000000000', deployerAddress);

        this.pantherPoolV1Impl = await MockPantherPoolV1.deploy(
            deployerAddress,
            this.zkpToken.address,
            this.pantherTaxiTree.address,
            this.pantherBusTree.address,
            this.pantherFerryTree.address,
            this.pantherStaticTreeProxy.address,
            vaultProxy.address,
            this.zAssetsRegistryV1.address,
            this.prpVoucherGrantor.address,
            ADDRESS_ONE,
            this.pantherVerifier.address,
        );
        await this.pantherPoolV1Impl.deployed();

        await this.pantherPoolV1Proxy.upgradeTo(this.pantherPoolV1Impl.address);

        const VaultV1 = await ethers.getContractFactory('VaultV1');

        const vaultImpl = await VaultV1.deploy(this.pantherPoolV1Proxy.address);

        await vaultProxy.upgradeTo(vaultImpl.address);

        this.testAmount = BigNumber.from(Math.floor(Math.random() * 1000));

        await this.erc20Token.transfer(
            this.accountOwner.address,
            parseEther('100'),
        );

        const Vault_1 = await ethers.getContractFactory('VaultV1');

        this.vault = Vault_1.attach(vaultProxy.address);

        const PrpConverter = await ethers.getContractFactory('PrpConverter');

        this.prpConverter = await PrpConverter.deploy(
            deployerAddress,
            this.zkpToken.address,
            this.pantherPoolV1Proxy.address,
            this.vault.address,
        );

        const EntryPoint = await ethers.getContractFactory('EntryPoint');

        this.entryPoint = await EntryPoint.deploy();

        const poolMainSelector = ethers.utils
            .id(
                'main(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint8,uint96,bytes)',
            )
            .slice(0, 10);

        const activateZAccountSelector = ethers.utils
            .id(
                'activateZAccount(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10);

        const claimRewardsSelector = ethers.utils
            .id(
                'claimRewards(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,bytes)',
            )
            .slice(0, 10);

        const convertSelector = ethers.utils
            .id(
                'convert(uint256[],((uint256,uint256),(uint256[2],uint256[2]),(uint256,uint256)),uint32,uint96,uint96,bytes)',
            )
            .slice(0, 10);

        this.smartAccount = await (
            await ethers.getContractFactory('Account')
        ).deploy(
            [
                this.pantherPoolV1Proxy.address,
                this.zAssetsRegistryV1.address,
                this.prpVoucherGrantor.address,
                this.prpConverter.address,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
                ADDRESS_ONE,
            ],
            [
                poolMainSelector,
                activateZAccountSelector,
                claimRewardsSelector,
                convertSelector,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
                BYTES_ONE,
            ],
            [356, 324, 324, 356, 0, 0, 0, 0],
        );

        const PayMasterFactory = await ethers.getContractFactory('PayMaster');

        const paymasterImpl = await PayMasterFactory.deploy(
            this.entryPoint.address,
            this.smartAccount.address,
            this.broker.address,
            this.prpVoucherGrantor.address,
        );

        this.paymasterProxy.upgradeTo(paymasterImpl.address);

        this.pantherPool = MockPantherPoolV1.attach(
            this.pantherPoolV1Proxy.address,
        );

        this.paymaster = PayMasterFactory.attach(this.paymasterProxy.address);
        // await this.pantherPool.updateVaultAssetUnlocker(
        //     this.paymaster.address,
        //     true,
        // );

        await this.pantherPool.updateMainCircuitId(this.cirquitId);

        `    // await this.pantherPool.updateZAccountRegistrationCircuitId(
        //     this.cirquitId,
        // );`;

        this.PAYMASTER_VOUCHER_TYPE_ID = ethers.utils
            .id('panther-paymaster-refund-grantor')
            .slice(0, 10);

        await this.prpVoucherGrantor.updateVoucherTerms(
            this.paymasterProxy.address,
            this.PAYMASTER_VOUCHER_TYPE_ID,
            100e9,
            100e9,
            true,
        );

        await this.ethersSigner.sendTransaction({
            to: this.broker.address,
            value: 100e9,
        });

        const zAccountsRegistry = await smock.fake('ZAccountsRegistry');
        const zZonesRegistry = await smock.fake('ZZonesRegistry');
        this.pantherStaticTree = await (
            await ethers.getContractFactory('PantherStaticTree', {
                libraries: {
                    PoseidonT6: poseidonT6.address,
                },
            })
        ).deploy(
            deployerAddress,
            this.zAssetsRegistryV1.address,
            zAccountsRegistry.address,
            this.zNetworksRegistry.address,
            zZonesRegistry.address,
            this.providersKeys.address,
        );

        await this.pantherStaticTreeProxy.upgradeTo(
            this.pantherStaticTree.address,
        );
    }
}

export function buildOp(params?: UserOperationStruct): UserOperationStruct {
    return {
        sender: params?.sender ?? ADDRESS_ONE,
        nonce: params?.nonce ?? 0,
        initCode: params?.initCode ?? '0x',
        callData: params?.callData ?? '0x',
        callGasLimit: params?.callGas ?? BigNumber.from(0),
        verificationGasLimit: params?.verificationGas ?? BigNumber.from(0),
        preVerificationGas: params?.preVerificationGas ?? BigNumber.from(0),
        maxFeePerGas: params?.maxFeePerGas ?? BigNumber.from(0),
        maxPriorityFeePerGas: params?.maxPriorityFeePerGas ?? BigNumber.from(0),
        paymasterAndData: params?.paymasterAndData ?? '0x',
        signature: params?.signature ?? BYTES64_ZERO,
    };
}

export async function setupInputFields(
    lockData: LockDataStruct,
    paymasterCompensation: BigNumber,
    cachedForestRootIndex: string,
    privateMessage: string,
    vault: string,
): BigNumberish[] {
    const inputs = await depositInputs();

    inputs.maticTokenType = lockData.tokenType;
    inputs.token = lockData.token;
    inputs.saltHash = lockData.saltHash;
    inputs.depositAmount = lockData.extAmount;
    inputs.kytDepositSignedMessageReceiver = vault;
    inputs.kytDepositSignedMessageSender = lockData.extAccount;

    inputs.extraInputsHash = generateExtraInputsHash(
        ['uint32', 'uint8', 'uint96', 'bytes'],
        [
            cachedForestRootIndex,
            lockData.tokenType,
            paymasterCompensation,
            privateMessage,
        ],
    );

    return inputs;
}

export function composeERC20SenderStealthAddress(
    lockData: SaltedLockDataStruct,
    vault: string,
): string {
    const execData2 = composeExecData(lockData, vault);

    const initCode2 = ethers.utils.solidityPack(
        ['bytes', 'address', 'bytes'],
        [
            '0x3d6014602a3d395160601C3d3d603e80380380913d393d343d955af16026573d908181803efd5b80f300',
            lockData.token,
            execData2,
        ],
    );

    return ethers.utils.getCreate2Address(
        vault,
        lockData.saltHash,
        ethers.utils.keccak256(initCode2),
    );
}

export function composeETHEscrowStealthAddress(
    lockData: SaltedLockDataStruct,
    vault: string,
) {
    const initCode = composeExecData(lockData, vault);

    const initCodeSalt = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ['bytes32', 'address'],
            [lockData.saltHash, lockData.extAccount],
        ),
    );

    return ethers.utils.getCreate2Address(
        vault,
        initCodeSalt,
        ethers.utils.keccak256(initCode),
    );
}
