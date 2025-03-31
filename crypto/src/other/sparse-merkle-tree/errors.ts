// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-25 Panther Protocol Foundation

export class AbstractedSubtreeProofError extends Error {
    constructor() {
        super('Cannot generate proof from abstracted subtree');
    }
}

export class LeafIndexOutOfBound extends Error {
    constructor(index: number) {
        super(`Leaf index out of bound: ${index}`);
    }
}

export class InvalidSubtreeIndex extends Error {
    constructor(index: number) {
        super(`Invalid subtree index: ${index}`);
    }
}
