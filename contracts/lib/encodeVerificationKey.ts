// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import Web3 from 'web3';

const web3 = new Web3();

function encodeVerificationKey(vk: VerificationKey): string {
    const {vk_alpha_1, vk_beta_2, vk_gamma_2, vk_delta_2, IC} = vk;

    return web3.eth.abi.encodeParameters(
        [
            'tuple(tuple(uint256, uint256), tuple(uint256[2], uint256[2]), tuple(uint256[2], uint256[2]), tuple(uint256[2], uint256[2]), tuple(uint256, uint256)[])',
        ],
        [
            [
                [vk_alpha_1[0], vk_alpha_1[1]],
                [
                    [vk_beta_2[0][1], vk_beta_2[0][0]],
                    [vk_beta_2[1][1], vk_beta_2[1][0]],
                ],
                [
                    [vk_gamma_2[0][1], vk_gamma_2[0][0]],
                    [vk_gamma_2[1][1], vk_gamma_2[1][0]],
                ],
                [
                    [vk_delta_2[0][1], vk_delta_2[0][0]],
                    [vk_delta_2[1][1], vk_delta_2[1][0]],
                ],
                IC.map(item => [item[0], item[1]]),
            ],
        ],
    );
}

type VerificationKey = {
    protocol?: string;
    curve?: string;
    nPublic?: number;
    vk_alpha_1: string[];
    vk_beta_2: string[][];
    vk_gamma_2: string[][];
    vk_delta_2: string[][];
    vk_alphabeta_12?: string[][][];
    IC: string[][];
};

export {encodeVerificationKey};
