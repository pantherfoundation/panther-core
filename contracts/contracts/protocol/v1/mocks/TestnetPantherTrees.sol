// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2024 Panther Ventures Limited Gibraltar
// solhint-disable one-contract-per-file
pragma solidity ^0.8.19;

// import "../PantherTrees.sol";
// import { FeeParams } from "../feeMaster/Types.sol";

// interface IFeeParamsGetter {
//     function feeParams() external view returns (FeeParams memory);
// }

// contract TestnetPantherTrees is PantherTrees {
//     bytes32[50] private _startGap;

//     // avg number of utxos which can be added per minute
//     uint16 public perMinuteUtxosLimit;

//     // keeps track of the timestamp of the latest added utxos
//     // lastUtxoUpdateBlockNum
//     uint32 public lastUtxoSimulationTimestamp;

//     constructor(
//         address _owner,
//         address _pantherPool,
//         address _pantherVerifier,
//         address _feeMaster,
//         address _zkpToken,
//         uint8 _miningRewardVersion,
//         PantherStaticTrees memory pantherStaticTrees
//     )
//         PantherTrees(
//             _owner,
//             _pantherPool,
//             _pantherVerifier,
//             _feeMaster,
//             _zkpToken,
//             _miningRewardVersion,
//             pantherStaticTrees
//         )
//     {}

//     function getPerUtxoReward() public view returns (uint256) {
//         FeeParams memory feeParams = IFeeParamsGetter(FEE_MASTER).feeParams();
//         return feeParams.scPerUtxoReward * 1e12;
//     }

//     function getAllowedUtxosAt(
//         uint256 _timestamp
//     ) public view returns (uint256 allowedUtxos) {
//         if (_timestamp <= lastUtxoSimulationTimestamp) return 0;

//         uint256 secs = _timestamp - lastUtxoSimulationTimestamp;
//         // divide before multiply, since fake utxos are allowed to be created per minute (not second)
//         return (secs / 60 seconds) * perMinuteUtxosLimit;
//     }

//     function updatePerMinuteUtxosLimit(
//         uint16 _perMinuteUtxosLimit
//     ) external onlyOwner {
//         perMinuteUtxosLimit = _perMinuteUtxosLimit;
//     }

//     function simulateAddUtxosToBusQueue() external {
//         uint256 _counter = uint256(utxoCounter);

//         // generating the first utxo
//         uint256 utxo = uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE;

//         // Generating the utxos length between 1 - 4
//         uint256 length = (utxo & 3) + 1;

//         if (length > getAllowedUtxosAt(block.timestamp)) return;

//         bytes32[] memory utxos = new bytes32[](length);

//         // adding the first commitment
//         utxos[0] = bytes32(utxo);
//         _counter++;

//         // adding the rest of commitment
//         for (uint256 i = 1; i < length; ) {
//             utxos[i] = bytes32(
//                 uint256(keccak256(abi.encode(_counter))) % FIELD_SIZE
//             );

//             unchecked {
//                 i++;
//                 _counter++;
//             }
//         }

//         // overflow risk ignored
//         utxoCounter = uint32(_counter);
//         lastUtxoSimulationTimestamp = uint32(block.timestamp);

//         uint256 basePerUtxoReward = getPerUtxoReward();
//         uint256 reward = basePerUtxoReward * length;

//         _addUtxosToBusQueue(utxos, uint96(reward));
//     }
// }
