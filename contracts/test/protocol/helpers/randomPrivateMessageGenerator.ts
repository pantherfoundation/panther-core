// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {ethers} from 'ethers';

const zAccountUtxoMessageType = 0x06; // prefix for zAccount utxo
const ephemeralKey = ethers.utils.hexlify(ethers.utils.randomBytes(32));
const cypherText = ethers.utils.hexlify(ethers.utils.randomBytes(64));

const privateMessage =
    zAccountUtxoMessageType +
    ephemeralKey.substring(2) +
    cypherText.substring(2);

export {privateMessage};
