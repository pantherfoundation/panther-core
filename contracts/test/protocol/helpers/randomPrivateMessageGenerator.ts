// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {ethers} from 'ethers';

const zAccountUtxoMessageType = 0x06; // prefix for zAccount utxo
const ephemeralKey = ethers.utils.hexlify(ethers.utils.randomBytes(32));
const cypherText = ethers.utils.hexlify(ethers.utils.randomBytes(64));

const privateMessage =
    zAccountUtxoMessageType +
    ephemeralKey.substring(2) +
    cypherText.substring(2);

export {privateMessage};
