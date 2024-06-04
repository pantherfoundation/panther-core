// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../../../common/ImmutableOwnable.sol";
import "../interfaces/IPluginRegistry.sol";

contract PluginRegistry is ImmutableOwnable, IPluginRegistry {
    // Mapping to store allowed plugins associated with destinations and their allowed functions
    // Mapping (plugin address -> destination address -> function selector)
    mapping(address => bool) public allowedPlugins;

    // mapping to store cirquitIds: bytes4(keccak256(`circuit-name`)) => uint160
    mapping(bytes4 => uint160) public cirquitIDs;

    mapping(address => bool) public vaultAssetUnlockers;

    // Event to log the registration of a new contract and its function
    event PluginRegistered(address pluginAddress);
    event PluginUnregistered(address pluginAddress);
    event CircuitIdRegistered(bytes _cirquitName, uint160 _cirquitId);
    event VaultAssetUnlockerUpdated(address newAssetUnlocker, bool status);

    constructor(address _owner) ImmutableOwnable(_owner) {}

    // Function to register a plugin along with the function selector and destination that is allowed
    function registerPlugin(address _plugin) external onlyOwner {
        allowedPlugins[_plugin] = true;
        emit PluginRegistered(_plugin);
    }

    //     Function to unregister a plugin
    function _unregisterPlugin(address _plugin) external onlyOwner {
        require(allowedPlugins[_plugin], "ERR_NOT_REGISTERED_PLUGIN");
        delete allowedPlugins[_plugin];
        emit PluginUnregistered(_plugin);
    }

    function isRegistered(address plugin) external view returns (bool) {
        return allowedPlugins[plugin];
    }

    // Function to register a plugin along with the function selector and destination that is allowed
    function updateCirquitId(
        bytes memory cirquitName,
        uint160 cirquitId
    ) external onlyOwner {
        bytes4 cirquitKey = bytes4(keccak256(cirquitName));
        cirquitIDs[cirquitKey] = cirquitId;
        emit CircuitIdRegistered(cirquitName, cirquitId);
    }

    function getCirquitIdByName(
        bytes memory cirquitName
    ) external returns (uint160) {
        bytes4 cirquitKey = bytes4(keccak256(cirquitName));
        return cirquitIDs[cirquitKey];
    }

    function getCirquitIdBySigHash(
        bytes4 cirquitIdSigHash
    ) external returns (uint160) {
        return cirquitIDs[cirquitIdSigHash];
    }

    function updateVaultAssetUnlocker(
        address _unlocker,
        bool _status
    ) external onlyOwner {
        vaultAssetUnlockers[_unlocker] = _status;

        emit VaultAssetUnlockerUpdated(_unlocker, _status);
    }

    function requireAllowedUnlocker(address caller) external view {
        require(vaultAssetUnlockers[caller], "ERR_UNAUTHORIZED");
    }
}
