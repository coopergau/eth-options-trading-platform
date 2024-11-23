// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Script} from "lib/forge-std/src/Script.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployOptionsMarketplace is Script {
    function run() external returns (OptionsMarketplace) {
        HelperConfig helperConfig = new HelperConfig();

        vm.startBroadcast();
        OptionsMarketplace optionsMarketplace = new OptionsMarketplace(helperConfig.btcEthPriceFeed());
        vm.stopBroadcast();

        return optionsMarketplace;
    }
}
