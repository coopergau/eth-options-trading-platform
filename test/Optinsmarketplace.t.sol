// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOptionsMaketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";

contract OptionsMarketplaceTest is Test {
    OptionsMarketplace optionsMarketplace;
    function setup() external {
        DeployOptionsMarketplace deployer = new DeployOptionsMarketplace();
        optionsMarketplace = deployer.run();
    }
}
