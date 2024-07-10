// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: Copyright 2021-24 Panther Ventures Limited Gibraltar

import {BusTree} from './bus-tree';
import {FOREST_TREE_DEPTH} from './constants';
import {SparseMerkleTree} from './sparse-merkle-tree';

/** 
 * note: there is not zero leaf needed for the forest root.
 ```txt
                             Forest root
                              -----------
                                   | +2 levels for
                                   | 4 (main) trees
                                   | Maintained on every supported network
                   +---------------+--------------+
                  /                                \
                 0                                  1
               /   \                              /   \
              0     1                            0     1
   "Taxi" tree|     |"Bus" tree      "Ferry" tree|     |Static tree
   -----------+     +---------       ------------+     +------------
   ```
 */

export class ForestTree {
    private tree: SparseMerkleTree;
    public readonly depth: number = FOREST_TREE_DEPTH;

    constructor(
        taxiTree: AbstractTree,
        busTree: AbstractTree<BusTree>,
        ferryTree: AbstractTree,
        staticTree: AbstractTree,
    ) {
        const leaves = [taxiTree, busTree, ferryTree, staticTree].map(
            getAbstractTreeRoot,
        );
        this.tree = new SparseMerkleTree(leaves, this.depth);
    }

    public getRoot() {
        return this.tree.getRoot();
    }

    public getProof() {
        throw new Error('[ForestTree] not implemented yet');
    }

    static getForestRoot(
        taxiTree: AbstractTree,
        busTree: AbstractTree<BusTree>,
        ferryTree: AbstractTree,
        staticTree: AbstractTree,
    ): bigint {
        const tree = new ForestTree(taxiTree, busTree, ferryTree, staticTree);
        return tree.getRoot();
    }
}

export type AbstractTree<
    T extends BusTree | SparseMerkleTree = SparseMerkleTree,
> = bigint | T;

function getAbstractTreeRoot<T extends BusTree | SparseMerkleTree>(
    tree: AbstractTree<T>,
): bigint {
    if (tree instanceof BusTree || tree instanceof SparseMerkleTree)
        return tree.getRoot();
    return tree;
}
