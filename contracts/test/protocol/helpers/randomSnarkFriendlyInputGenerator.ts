// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {ethers} from 'ethers';

const randomInputGenerator = () => {
    const randomInput = ethers.BigNumber.from(ethers.utils.randomBytes(32))
        .mod(SNARK_FIELD_SIZE)
        .toHexString();

    return ethers.utils.hexZeroPad(randomInput, 32);
};

export {randomInputGenerator};
