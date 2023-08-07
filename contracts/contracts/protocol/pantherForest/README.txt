# Architecture of Panther Merkle Trees

## Major changes
Changes of the "old architecture" (see the description in the edn of this doc):
- Gas-expensive on-chain UTXO tree rebuilding on every MASP transaction replaced
  by much cheaper off-chain rebuilding, verified on-chain with SNARK proof for a
  batch of MASP transactions at once
- Multiple shallow UTXO trees replaced by single deep UTXO tree, one per network,
  that is to be synchronised between networks
- All trees (including "static" ones) on a network joined under the Forest Root
- "Miners" and "Keepers" introduced

## Structure of Panther Merkle Trees
```
                              Forest Tree
                              on every chain
                              -----+--------
                                   |quad-tree
                                   |1 level
                                   |= 4 leafs
                                   |are roots of trees 0..3
                 +---+-------------+-----------+----+
                /   /                           \    \
               /   /                             \    \
              0    1                              2    3
   "Taxi" tree|    |"Bus" tree         "Ferry" tree|   |"Static" tree
on every chain|    |on every chain   on every chain|   |on mainnet only
--------------+    +--------------   --------------+   +---------------
   binary tree|    |binary tree         binary tree|   |quin-tree
      6 levels|    |26 levels              6 levels|   |1 level
     =64 UTXOs|    |=62M UTXOs            =64 leafs|   |=5 leafs
                                       are roots of|   |are roots of
                                   chains Bus trees|   |(trees on mainnet):
                                                       |- zAssets tree
                                                       |  of 20 levels
                                                       |- zZones tree
                                                       |  of 16 levels
                                                       |- TrustProviderKeys tree
                                                       |  of 16 levels
                                                       |- zAccountBlacklist tree
                                                       |  of 16 levels
                                                       |- zNetworks tree
                                                       |  of 6 levels

"Single-chain" setup assumes all trees (incl. "static" ones) are on Polygon.
```

### How it "works"
1. A UTXO (no matter if it's the zAsset or zAccount one) may reside in the Taxi,
   the Bus, and the Ferry trees:
   depending on user choice and sync state, at some point in time, a UTXO may be
   included either in the Taxi tree only, or in the Bus tree only, or in the Bus
   tree and the Ferry tree, or in all the 3 trees.
2. The Static tree does not contain UTXOs.
3. Users, without Miners, may insert UTXOs they create in the Taxi tree only.
   Miners only may update the root of the Bus tree, thus inserting user UTXOs in
   the tree. Users may only request Miners to insert user UTXOs to the Bus tree,
   appending UTXOs to a "queue" for Miners.
   Finally, Keepers only may update the root of the Ferry tree if and only if
   the Bus tree root on at least one of the supported networks has been changed.
4. To be immediately spendable on the network where it is created (but not on
   other network), a UTXO, when created, must be inserted in the "Taxi" tree.
   Doing a MASP tx, a user may opt, whether a new UTXO should be immediately
   spendable within the same tx (or very soon after), or the user agrees to wait
   until his new UTXO becomes spendable later, when Miners insert the UTXO into
   the Bus tree.
5. The "Taxi" tree is rebuild by the smart contract (hashes computed on-chain),
   and the tree root (as well as the Forest root) gets updated immediately.
   Because of the on-chain rebuilding, there are no "race condition" for users,
   and a correct transaction is guaranteed to be accepted.
   The tree is re-writable: every time there is no more space in the tree, UTXOs
   inserted first get updated with new ones.
   However, since the (limited) history of the seen Forest root is saved, the
   former roots of the Taxi tree (and thus re-written UTXOs) may be referenced to
   for some time even after a UTXO has been re-written.
6. No matter if User chooses the "taxi", or the "Bus", new UTXOs are appended to
   the "Queued Batches" for Miners.
7. Miners insert UTXOs in batches, 64 UTXOs at once, proving correctness of an
   insertion with a SNARK proof rather than computing hashes on-chain.
   This way, gas cost per UTXO is much lower than on-chain re-building the tree
   would take (on-chain SNARK verification costs less).
   Note, however, it introduces "race condition", so a Miner is not guaranteed a
   properly prepared insertion will be accepted by the smart contract as other
   Miners may update the tree root before execution of the former insertion.
8. The Ferry tree consists of the roots of the Bus trees on all networks.
   UTXOs may "get into" the tree only via the Bus tree, the root of which gets
   included in the Ferry tree.
9. "Keepers" update the root of the "Ferry" tree in the process of syncing the
   Bus tree roots between networks. It may be done with or without SNARK proving
   (to be decide).
10.A UTXO created on one network may be spent on another network only when the
   UTXO gets into the Bus tree on this first network, then the Ferry tree root
   gets updated on "another" network to include the new root of that Bus tree.
   In other words, in order a UTXO to be included in the Ferry tree, first Miners
   shall insert the batch with that UTXO to the Bus tree on the network the MASP
   tx take place at, and then Keepers shall update the new root of the Ferry tree
   on the network where the UTXO is to be spent.
11.The Static tree gets hashed into the Forest root to decrease a public inputs
   to the on-chain verifier. It contains relatively rare updated params. These
   params (i.e. the root of the static tree) shall be the same on all networks.
   !!! Update of the Static tree root resets (cleans) the history of the Forest
   roots.
12.The Forest root is unique on every network. The contract keeps a history of,
   say, 256 latest seen roots, and users may refer to any of the root saved on
   the history.
13.The Forest tree root gets updated by the smart contract on-chain every time:
   - User inserts UTXO(s) into the Taxi tree
   - Miner inserts a batch into the Bus tree
   - Keepers update the root of the Ferry tree
   - Any of the Static tree's subtrees gets updated.

## Panther Trees: Strategy of syncing between supported networks

Data / and (config) params to share & sync between networks:
- UTXO "Bus" tree root from every supported network
- zAccount UTXOs
- TrustProvidersKeys global tree root
- zAccountBlacklist global tree root
- zAssets global tree root
- zZones global tree root
- zNetworks global tree root

------------------------------|-------------------------------------------------
Data kind                     | Sync strategy
------------------------------|-------------------------------------------------
UTXO trees roots              | Keepers trigger sending network's Bus tree root
                              | to a contract on the mainnet which computes the
                              | new Ferry tree root (of all networks Bus roots).
                              | Keepers propagates the root to other networks.
zAccount UTXOs                | Created on every network a user operates, and it
                              | gets to the Bus / Taxi tree on that network.
zAccountBlacklist global root | The DAO updates it on the mainnet. Then keepers
                              | propagate the root to other networks.
TrustProvidersKeys global root| Trust providers update the tree on the mainnet.
                              | Keepers propagate the root to other networks.
zAssets global root           | The DAO updates it on the mainnet.
                              | Keepers propagate the root to other networks.
zZones global root            | DAO and Zone Operators update it on the mainnet.
                              | Keepers propagate the root to other networks.
zNetworks global tree root    | The DAO updates it on the mainnet.
                              | Keepers propagate the root to other networks.


## Panther Trees: Smart contracts hierarchy

### Single-chain architecture

#### Smart contracts on Polygon
```
Proxy -> PantherPool
         |-is-> PantherForest // immutable links to proxies of "trees"
         |      | // These contracts have immutable link to PantherPool.Proxy
         |      |-> Proxy->PantherTaxiTree
         |      |-> Proxy->PantherBusTree
         |      |-> Proxy->PantherFerryTree (hard-coded root)
         |      +-> Proxy->PantherStaticTree // immutable links to proxies of "registries"
         |                 | // These contracts have immutable link to PantherStaticTree.Proxy
         |                 |-> Proxy->TrustProvidersRegistry
         |                 |-> Proxy->ZAccountRegistry
         |                 |-> Proxy->ZAssetsRegistry
         |                 |-> Proxy->ZZonesRegistry (for "single-zone" - hard-coded root)
         |                 +-> Proxy->ZNetworkRegistry (hard-coded root)
         |--> Proxy->PantherVault
         |--> PantherVerifier
         +--> multiple deployed verification keys

```

### Multi-chain architecture

#### Smart contracts on Ethereum mainnet

Similar to the "single-chain" architecture
(all "hard-coded root" contracts replaced with full implementations).

#### Smart contracts on other supported network
```
Proxy -> PantherPool // immutable links to PantherVault.Proxy, PantherVerifier and verification keys
         |-is-> PantherForest // immutable links to proxies of "trees"
         |      | // non-mock "trees" have immutable link to PantherPool.Proxy
         |      |-> Proxy->PantherTaxiTree
         |      |-> Proxy->PantherBusTree
         |      |-> Proxy->PantherFerryTreeRoot
         |      +-> Proxy->PantherStaticTreeRoot
         |--> Proxy->PantherVault
         |--> PantherVerifier
         +--> multiple deployed verification keys
```
