// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {EntryPoint} from "../lib/account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address entryPoint;
        address account;
    }
    uint256 private constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 private constant LOCAL_CHAIN_ID = 31337;
    address private constant BURNER_WALLET =
        0xFA84EA29C6cfaEf505059B372262F3D3e3f54Ab2;
    // address private constant FOUNDRY_DEFAULT_SENDER =
    // 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address private constant ANVIL_DEFAULT_ACCOUNT =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    NetworkConfig private localNetworkConfig;
    mapping(uint256 => NetworkConfig) private networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(
        uint256 chainid
    ) public returns (NetworkConfig memory) {
        if (chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else if (networkConfigs[chainid].account == address(0)) {
            revert HelperConfig__InvalidChainId();
        }
        return networkConfigs[chainid];
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789,
                account: BURNER_WALLET
            });
    }

    function getZkSyncSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
                entryPoint: address(entryPoint),
                account: ANVIL_DEFAULT_ACCOUNT
            });

        return localNetworkConfig;
            
    }
}
