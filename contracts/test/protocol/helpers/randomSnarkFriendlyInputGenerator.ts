// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar

import {SNARK_FIELD_SIZE} from '@panther-core/crypto/src/utils/constants';
import {ethers} from 'ethers';

const randomInputGenerator = () => {
    return ethers.BigNumber.from(ethers.utils.randomBytes(32))
        .mod(SNARK_FIELD_SIZE)
        .toString();
};

export {randomInputGenerator};
