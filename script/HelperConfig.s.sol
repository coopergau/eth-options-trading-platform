// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract HelperConfig is Script {
    address public immutable btcEthPriceFeed;

    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant SEPOLIA_TESTNET_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_TESTNET_CHAIN_ID = 31337;

    address public constant MAINNET_BTC_ETH_PRICEFEED = 0xdeb288F737066589598e9214E782fa5A8eD689e8;
    address public constant SEPOLIA_BTC_ETH_PRICEFEED = 0x5fb1616F78dA7aFC9FF79e0371741a747D2a7F22;

    int256 public constant MOCK_BTC_ETH_PRICE = 30e18;
    uint8 public constant ETH_DECIMALS = 18;

    constructor() {
        if (block.chainid == ETH_MAINNET_CHAIN_ID) {
            btcEthPriceFeed = MAINNET_BTC_ETH_PRICEFEED;
        } else if (block.chainid == SEPOLIA_TESTNET_CHAIN_ID) {
            btcEthPriceFeed = SEPOLIA_BTC_ETH_PRICEFEED;
        } else if (block.chainid == ANVIL_TESTNET_CHAIN_ID) {
            vm.startBroadcast();
            MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(ETH_DECIMALS, MOCK_BTC_ETH_PRICE);
            vm.stopBroadcast();
            btcEthPriceFeed = address(mockV3Aggregator);
        }
    }
}
