// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
//import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DeployOptionsMarketplace is Script {
    address public constant MAINNET_PRICE_FEED_ID =
        0xdeb288F737066589598e9214E782fa5A8eD689e8;

    function run() external returns (OptionsMarketplace) {
        /*uint256 decimals = 18;
        uint256 btcEthPrice = 30;
        MockV3Aggregator v3Aggregator = new MockV3Aggregator(decimals, btcEthPrice); */
        vm.startBroadcast();
        OptionsMarketplace optionsMarketplace = new OptionsMarketplace(
            MAINNET_PRICE_FEED_ID
        );
        vm.stopBroadcast();

        return optionsMarketplace;
    }
}
