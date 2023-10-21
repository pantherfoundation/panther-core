// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {privateMessage} from '../../helpers/randomPrivateMessageGenerator';
import {randomInputGenerator} from '../../helpers/randomSnarkFriendlyInputGenerator';

const inputs: string[] = [];
inputs[0] = randomInputGenerator(); // extraInputsHash
inputs[1] = '0'; // chargedAmountZkp
inputs[2] = (Math.ceil(Date.now() / 1000) + 86400).toString(); // createTime
inputs[3] = '0'; // depositAmountPrp
inputs[4] = '500'; // withdrawAmountPrp
inputs[5] = randomInputGenerator(); // utxoCommitmentPrivatePart
inputs[6] = randomInputGenerator(); // utxoSpendPubKeyX
inputs[7] = randomInputGenerator(); // utxoSpendPubKeyY
inputs[8] = '12'; // zAssetScale
inputs[9] = randomInputGenerator(); // zAccountUtxoInNullifier
inputs[10] = randomInputGenerator(); // zAccountUtxoOutCommitment
inputs[11] = '80001'; // zNetworkChainId
inputs[12] = randomInputGenerator(); // forestMerkleRoot
inputs[13] = randomInputGenerator(); // saltHash
inputs[14] = randomInputGenerator(); // magicalConstraint

const proof = {
    a: {x: randomInputGenerator(), y: randomInputGenerator()},
    b: {
        x: [randomInputGenerator(), randomInputGenerator()],
        y: [randomInputGenerator(), randomInputGenerator()],
    },
    c: {x: randomInputGenerator(), y: randomInputGenerator()},
};

const cachedForestRootIndex = '0';

const prpClaimSample = {
    inputs,
    privateMessage,
    proof,
    cachedForestRootIndex,
};

export {prpClaimSample};
