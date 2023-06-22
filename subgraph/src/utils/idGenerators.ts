// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import {Bytes, ethereum} from '@graphprotocol/graph-ts';

export function generateEntityId(event: ethereum.Event): Bytes {
    return event.transaction.hash.concatI32(event.logIndex.toI32());
}
