// SPDX-License-Identifier: GPL-3.0-only
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/lib/utils/constants';
import {ethers} from 'ethers';

const randomInputGenerator = (length = 32) => {
    const randomInput = ethers.BigNumber.from(ethers.utils.randomBytes(length))
        .mod(SNARK_FIELD_SIZE)
        .toHexString();

    return ethers.utils.hexZeroPad(randomInput, length);
};

export {randomInputGenerator};
