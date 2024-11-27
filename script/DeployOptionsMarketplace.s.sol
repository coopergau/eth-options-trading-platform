// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/**
 * @dev This script deploys the OptionsMarketplace contract and uses a HelperConfig
 *      contract to provide the correct address of the BTC/ETH price feed.
 */
contract DeployOptionsMarketplace is Script {
    function run() external returns (OptionsMarketplace) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();
        OptionsMarketplace optionsMarketplace = new OptionsMarketplace(helperConfig.btcEthPriceFeed());
        vm.stopBroadcast();

        return optionsMarketplace;
    }
}
