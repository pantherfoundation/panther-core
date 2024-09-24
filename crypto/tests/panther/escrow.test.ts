// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {babyjub} from 'circomlibjs';
import {mulPointEscalar} from 'circomlibjs/src/babyjub';

import * as fieldOperations from '../../src/base/field-operations';
import {generateRandomKeypair} from '../../src/base/keypairs';
import {
    convertDataEscrowToScalars,
    encryptDataForEscrow,
    ephemeralPublicKeyBuilder,
    maskPoint,
    unmaskPoint,
} from '../../src/panther/escrow';
import {
    CommonEscrowData,
    DataEscrowData,
    EscrowType,
} from '../../src/types/escrow';
import {Keypair, Point, PublicKey} from '../../src/types/keypair';

import ephemeralPublicKeyBuilderData from './data/ephemeralPublicKeyBuilder';

jest.mock('../../src/base/field-operations');

const createMockData = (): CommonEscrowData => ({
    zAssetID: 0n,
    zAccountID: 33n,
    zAccountZoneId: 1n,
    zAccountNonce: 2n,
    utxoInMerkleTreeSelector: Array(2).fill(Array(32).fill(0n)),
    utxoInPathIndices: Array(2).fill(Array(32).fill(0n)),
    utxoInAmounts: [0n, 0n],
    utxoOutAmounts: [10n, 0n],
    utxoInOriginZoneIds: [0n, 0n],
    utxoOutTargetZoneIds: [1n, 0n],
    utxoOutSpendingPublicKeys: [
        [
            9665449196631685092819410614052131494364846416353502155560380686439149087040n,
            13931233598534410991314026888239110837992015348186918500560502831191846288865n,
        ],
        [0n, 1n],
    ],
    ephemeralPubKey: [
        4301916310975298895721162797900971043392040643140207582177965168853046592976n,
        815388028464849479935447593762613752978886104243152067307597626016673798528n,
    ],
});

const ESCROW_PUBLIC_KEYS = {
    DATA: [
        6461944716578528228684977568060282675957977975225218900939908264185798821478n,
        6315516704806822012759516718356378665240592543978605015143731597167737293922n,
    ],
    DAO: [
        6744227429794550577826885407270460271570870592820358232166093139017217680114n,
        12531080428555376703723008094946927789381711849570844145043392510154357220479n,
    ],
} as const;

const EXPECTED_ENCRYPTED_POINTS = {
    DATA: [
        [
            13448997628370172142121064540922161530131000291293757353976490406600659699485n,
            6786713265324802353836561761516675026132581641648269618031750582273380915074n,
        ],
        [
            4571540050240624494219405580583507049331981473711771943756884769018855623280n,
            21198610127396451809526754236892481138999958113447719990820486113837174916694n,
        ],
        [
            4033670544751227578052559269341339055518688085590815938396833382029764334912n,
            18354775240679013885485121089406497849546512162874668345566059410418709709673n,
        ],
        [
            20399286099278016462437314178100881060967018389578365954358985464840531062958n,
            16603415768633382355527893930917768290248723894235579106482928918104961601427n,
        ],
        [
            5465482396988413500244136121916137093725277189786903024771569541729342264602n,
            18052446522046943908230226084246345928969485773552410049729266016545084008699n,
        ],
        [
            12296015241185805645813252451366902176955110432166997758114703914076473480566n,
            20640217119393223723114928028264255300362752921338608507459601444462338718795n,
        ],
        [
            9543857838494654970399777461409295060991860277282271271366165506276941025267n,
            10640319856812298729186938394589122461231374039478038286491853387922985109395n,
        ],
        [
            16316923171052759190502076430083075231582942463614244885046756571940782113749n,
            8705376175596548806662826766037702236642974311830201086593732499508964520n,
        ],
        [
            14009366412221217138863529120356799739925282410826135633228742365215681098110n,
            13320090048181446201416279522323242712648198238420685144157745291106881279337n,
        ],
        [
            12532002519490190436214220231644858505936551570710292722418539394393539472942n,
            10516080860923901805925996803626947967959810157132218960043924430105688744218n,
        ],
        [
            10346448136845180430735982709674302600604226766160695898857955583867479620566n,
            1685237099490986177641221522256131190271058376455210394810325980710119110251n,
        ],
    ],
    DAO: [
        [
            12032028674386602247606112047856619939984457257499437643949614462266665472292n,
            10231473684893412031634651500584679273869045480560969585260750474375209497228n,
        ],
    ],
};

const MOCKED_EPHEMERAL_RANDOM = {
    DATA: 2508770261742365048726528579942226801565607871885423400214068953869627805520n,
    DAO: 2486295975768183987242341265649589729082265459252889119245150374183802141273n,
};

const DAO_MOCKED_EPHEMERAL_PUBLIC_KEY = [
    18172727478723733672122242648004425580927771110712257632781054272274332874233n,
    18696859439217809465524370245449396885627295546811556940609392448191776076084n,
];

const transposeMatrix = (matrix: bigint[][]): bigint[][] =>
    matrix[0].map((_, colIndex) => matrix.map(row => row[colIndex]));

describe('Data Escrow Encryption', () => {
    describe('#convertDataEscrowToScalars', () => {
        it('should correctly convert CommonEscrowData to scalar array for Data Escrow', () => {
            const output = convertDataEscrowToScalars(
                createMockData() as DataEscrowData,
            );
            expect(output).toEqual([0n, 2162689n, 2n, 0n, 0n, 10n, 0n, 1n, 0n]);
        });
    });

    describe('#encryptDataForEscrow', () => {
        const testEncryptDataForEscrow = (
            escrowType: EscrowType,
            publicKey: PublicKey,
            mockedRandom: bigint,
            expectedPoints: bigint[][],
        ) => {
            beforeEach(() => {
                (
                    fieldOperations.generateRandomInBabyJubSubField as jest.Mock
                ).mockReturnValue(mockedRandom);
            });

            it(`should return correct ephemeral keypair and encrypted points for ${escrowType} Escrow`, () => {
                const result = encryptDataForEscrow(
                    createMockData(),
                    publicKey,
                    escrowType,
                );
                const expectedEphemeralPubKey =
                    escrowType === EscrowType.Data
                        ? createMockData().ephemeralPubKey
                        : DAO_MOCKED_EPHEMERAL_PUBLIC_KEY;

                expect(result).toMatchObject({
                    ephemeralKeypair: {
                        privateKey: mockedRandom,
                        publicKey: expectedEphemeralPubKey,
                    },
                    escrowEncryptedPoints: transposeMatrix(expectedPoints),
                });
            });

            it(`should generate correct number of encrypted points for ${escrowType} Escrow`, () => {
                const result = encryptDataForEscrow(
                    createMockData(),
                    publicKey,
                    escrowType,
                );
                expect(result.escrowEncryptedPoints[0].length).toEqual(
                    expectedPoints.length,
                );
                expect(result.escrowEncryptedPoints[1].length).toEqual(
                    expectedPoints.length,
                );
            });
        };

        describe('Data Escrow', () => {
            testEncryptDataForEscrow(
                EscrowType.Data,
                ESCROW_PUBLIC_KEYS.DATA as PublicKey,
                MOCKED_EPHEMERAL_RANDOM.DATA,
                EXPECTED_ENCRYPTED_POINTS.DATA,
            );
        });

        describe('Zone and DAO Escrow', () => {
            testEncryptDataForEscrow(
                EscrowType.Zone,
                ESCROW_PUBLIC_KEYS.DAO as PublicKey,
                MOCKED_EPHEMERAL_RANDOM.DAO,
                EXPECTED_ENCRYPTED_POINTS.DAO,
            );
        });
    });
});

const generateSecretPoint = (): Point => {
    const secret = fieldOperations.generateRandomInBabyJubSubField();
    return mulPointEscalar(babyjub.Base8, secret) as Point;
};

describe('El Gamal', () => {
    let secretPoint: Point;
    let keypair: Keypair;

    beforeEach(() => {
        secretPoint = generateSecretPoint();
        keypair = generateRandomKeypair();
    });

    it('masks and unmasks single point', () => {
        const encryptedPoint = maskPoint(secretPoint, keypair.publicKey);
        const decryptedPoint = unmaskPoint(encryptedPoint, keypair.publicKey);
        expect(secretPoint).toEqual(decryptedPoint);
    });

    it('#ephemeralPublicKeyBuilder', () => {
        const keys = ephemeralPublicKeyBuilder(
            ephemeralPublicKeyBuilderData.ephemeralRandom,
            ephemeralPublicKeyBuilderData.pubKey as PublicKey,
            10,
        );
        expect(keys.ephemeralPubKeys).toHaveLength(10);
        expect(keys.sharedPubKeys).toHaveLength(10);
        expect(keys.ephemeralPubKeys).toEqual(
            ephemeralPublicKeyBuilderData.ephemeralPubKey,
        );
        expect(keys.sharedPubKeys).toEqual(
            ephemeralPublicKeyBuilderData.sharedPubKey,
        );
        expect(keys.hidingPoint).toEqual(
            ephemeralPublicKeyBuilderData.hidingPoint,
        );
    });
});
