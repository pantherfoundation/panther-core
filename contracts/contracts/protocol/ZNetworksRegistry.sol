// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar
pragma solidity 0.8.16;

import "./pantherForest/interfaces/ITreeRootGetter.sol";

contract ZNetworksRegistry is ITreeRootGetter {
    /**
     * ZNetworks tree root generation
     * This tree consists of 2 leafs: first leaf is for Goerli network and second one is for Mumbai
     * - List for Goerli:
     *      - leafIndex = 0
     *      - commitment = poseidon([
     *              // active
     *              1,
     *              // chainId
     *              5,
     *              // networkId
     *              1,
     *              // networkIDsBitMap:
     *              // One-bit flags enabling creating/spending on this network UTXOs spendable/created on
     *              // other networks; LS bit for the network with ID 1, followed by the bit for the ID 2, ...)
     *              // (networks with IDs 1 and 2 are enabled)
     *              3,
     *              // forTxReward
     *              0,
     *              // forUtxoReward
     *              1000
     *              // forDepositReward
     *              0
     *              // daoDataEscrowPubKey[0]
     *              12272087043529289524334796370800745508281317430063431496260996322077559426628n
     *              // daoDataEscrowPubKey[1]
     *              9194872949126287643523554866093178264045906284036198776275995684726142899669n
     *
     *          ]) = 0x1e11d3c31a82691f36c10d8501d9e0fb5c6a4dcddcbe93349512d09313ad8ec9
     *
     *      - siblings = [
     *              0x2caf2892c4eac8f126437b6faf9bd10990fb2f5e3e9f9041646059df91d90b67
     *              0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4
     *              0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8
     *              0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c
     *              0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800
     *              0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f
     *          ]
     * - List for Mumbai:
     *      - leafIndex = 1
     *      - commitment = poseidon([
     *              // active
     *              1,
     *              // chainId
     *              80001,
     *              // networkId
     *              2,
     *              // networkIDsBitMap:
     *              // One-bit flags enabling creating/spending on this network UTXOs spendable/created on
     *              // other networks; LS bit for the network with ID 1, followed by the bit for the ID 2, ...)
     *              // (networks with IDs 1 and 2 are enabled)
     *              3,
     *              // forTxReward
     *              0,
     *              // forUtxoReward
     *              1000
     *              // forDepositReward
     *              0
     *              // daoDataEscrowPubKey[0]
     *              12272087043529289524334796370800745508281317430063431496260996322077559426628n
     *              // daoDataEscrowPubKey[1]
     *              9194872949126287643523554866093178264045906284036198776275995684726142899669n
     *
     *          ]) = 0x2caf2892c4eac8f126437b6faf9bd10990fb2f5e3e9f9041646059df91d90b67
     *
     *      - siblings = [
     *              0x1e11d3c31a82691f36c10d8501d9e0fb5c6a4dcddcbe93349512d09313ad8ec9
     *              0x232fc5fea3994c77e07e1bab1ec362727b0f71f291c17c34891dd4faf1457bd4
     *              0x077851cf613fd96280795a3cabc89663f524b1b545a3b1c7c79130b0f7d251c8
     *              0x1d79fd0bc46f7ca934dbcd3386a06f03c43f497851b3815ee726e7f9b26e504c
     *              0x05c0c15753806f506f64c18bf07116542451822479c4a89305cd4eb7ee94c800
     *              0x2b56fd5e780ebebdacdd27e6464cf01aac089461a998814974a7504aabb2023f
     *          ]
     *
     */
    function getRoot() external pure returns (bytes32) {
        // 14012219796450685573713237305847642356367283250649627741328974142691321346497n
        return
            0x1efaa2a689ac8f5b9d97f7a963d6a34a8a806321a52a3db5720366b3ad0079c1;
    }
}
