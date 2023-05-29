// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-23 Panther Ventures Limited Gibraltar
pragma solidity ^0.8.16;

import "./QueuedBatches.sol";
import "./SnarkProvableInsertion.sol";

abstract contract BusTree is QueuedBatches, SnarkProvableInsertion {}
