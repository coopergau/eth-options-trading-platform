// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";
import {DeployOptionsMarketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";

// Contract tests reverts of if statements in the beginning of functions
contract Reverts is Test {
    OptionsMarketplace public optionsMarketplace;
    address public seller = address(1);
    address public buyer = address(2);
    uint256 public constant STARTING_BALANCE = 10 ether;

    // Variables for listing valid option
    uint256 public constant PREMIUM = 0.1 ether;
    uint256 public constant STRIKE_PRICE = 1 ether;
    uint256 public constant EXPIRATION = 3600; // One hour into the future
    bool public constant IS_CALL = true;

    function setUp() external {
        DeployOptionsMarketplace deployer = new DeployOptionsMarketplace();
        optionsMarketplace = deployer.run();
        vm.deal(seller, STARTING_BALANCE);
        vm.deal(buyer, STARTING_BALANCE);
    }

    // listOption reverts
    function testListOptionRevertsIfAmountSentIsNotStrikePrice() public {
        vm.prank(seller);
        vm.expectRevert(OptionsMarketplace.OptionsMarketplace__AmountSentIsNotStrikePrice.selector);
        optionsMarketplace.listOption{value: STRIKE_PRICE + 1}(PREMIUM, STRIKE_PRICE, EXPIRATION, IS_CALL);
    }

    function testListOptionRevertsIfExpirationTimestampHasPassed() public {
        // Set the current block's timestamp to after the expiration timestamp
        vm.warp(EXPIRATION + 1);

        vm.prank(seller);
        vm.expectRevert(OptionsMarketplace.OptionsMarketplace__ExpirationTimestampHasPassed.selector);
        optionsMarketplace.listOption{value: STRIKE_PRICE}(PREMIUM, STRIKE_PRICE, EXPIRATION, IS_CALL);
    }

    // Tests with the other functions often use this function to work with an already listed option.
    function helperListOption() internal returns (uint256) {
        vm.prank(seller);
        uint256 optionId =
            optionsMarketplace.listOption{value: STRIKE_PRICE}(PREMIUM, STRIKE_PRICE, EXPIRATION, IS_CALL);
        return optionId;
    }
    // changePremium reverts

    function testChangePremiumRevertsIfOptionDoesNotExist() public {
        uint256 invalidOptionId = 0;

        vm.prank(seller);
        vm.expectRevert(OptionsMarketplace.OptionsMarketplace__OptionDoesNotExist.selector);
        optionsMarketplace.changePremium(invalidOptionId, PREMIUM + 0.1 ether);
    }
    // buyOption reverts
    // redeemOption reverts
    // getAssetPrice reverts
    // getOptionInfo reverts
}
