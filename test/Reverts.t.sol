// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOptionsMarketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

// Contract tests reverts of if statements in the beginning of functions
contract Reverts is Test {
    OptionsMarketplace public optionsMarketplace;
    address public seller = address(1);
    address public buyer = address(2);
    uint256 public constant STARTING_BALANCE = 100 ether;

    // Variables for listing valid option
    uint256 public expiration;
    uint256 public constant SECONDS_PER_HOUR = 3600;
    uint256 public constant PREMIUM = 0.1 ether;
    uint256 public constant STRIKE_PRICE = 25 ether;
    bool public constant IS_CALL = true;

    uint256 public constant ANVIL_CHAIN_ID = 31337;

    function setUp() external {
        DeployOptionsMarketplace deployer = new DeployOptionsMarketplace();
        optionsMarketplace = deployer.run();
        vm.deal(seller, STARTING_BALANCE);
        vm.deal(buyer, STARTING_BALANCE);

        // Set the expiration variable to one hour into the future
        if (block.chainid == ANVIL_CHAIN_ID) {
            expiration = SECONDS_PER_HOUR;
        } else {
            expiration = block.timestamp + SECONDS_PER_HOUR;
        }
    }

    // listOption reverts
    function testListOptionRevertsIfAmountSentIsNotStrikePrice() public {
        vm.prank(seller);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__AmountSentIsNotStrikePrice
                .selector
        );
        optionsMarketplace.listOption{value: STRIKE_PRICE + 1}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );
    }

    function testListOptionRevertsIfExpirationTimestampHasPassed() public {
        // Set the current block's timestamp to after the expiration timestamp
        vm.warp(expiration + 1);

        vm.prank(seller);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__ExpirationTimestampHasPassed
                .selector
        );
        optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );
    }

    // The following tests often use options that have been listed and/or bought.
    function helperListOption() internal returns (uint256) {
        vm.prank(seller);
        uint256 optionId = optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );
        return optionId;
    }

    function helperBuyOption(uint256 _optionId) internal {
        vm.prank(buyer);
        optionsMarketplace.buyOption{value: PREMIUM}(_optionId);
    }

    // changePremium reverts
    function testChangePremiumRevertsIfOptionDoesNotExist() public {
        uint256 invalidOptionId = 0;

        vm.prank(seller);
        vm.expectRevert(
            OptionsMarketplace.OptionsMarketplace__OptionDoesNotExist.selector
        );
        optionsMarketplace.changePremium(invalidOptionId, PREMIUM + 0.1 ether);
    }

    function testChangePremiumRevertsIfNotTheSeller() public {
        uint256 optionId = helperListOption();

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__YouAreNotTheSellerOfThisOption
                .selector
        );
        optionsMarketplace.changePremium(optionId, PREMIUM + 0.1 ether);
    }

    function testChangePremiumRevertsIfOptionAlreadyBought() public {
        uint256 optionId = helperListOption();
        helperBuyOption(optionId);

        vm.prank(seller);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__OptionHasAlreadyBeenBought
                .selector
        );
        optionsMarketplace.changePremium(optionId, PREMIUM + 0.1 ether);
    }

    // buyOption reverts
    function testbuyOptionRevertsIfOptionDoesNotExist() public {
        uint256 invalidOptionId = 0;

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace.OptionsMarketplace__OptionDoesNotExist.selector
        );
        optionsMarketplace.buyOption{value: PREMIUM}(invalidOptionId);
    }

    function testbuyOptionRevertsIfOptionAlreadyBought() public {
        uint256 optionId = helperListOption();
        helperBuyOption(optionId);

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__OptionHasAlreadyBeenBought
                .selector
        );
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);
    }

    function testbuyOptionRevertsIfAmountSentIsNotPremium() public {
        uint256 optionId = helperListOption();

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__SentIncorrectAmountOfEth
                .selector
        );
        optionsMarketplace.buyOption{value: PREMIUM + 0.1 ether}(optionId);
    }

    // redeemOption reverts
    function testRedeemOptionRevertsIfOptionDoesNotExist() public {
        uint256 invalidOptionId = 0;

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace.OptionsMarketplace__OptionDoesNotExist.selector
        );
        optionsMarketplace.redeemOption(invalidOptionId);
    }

    function testRedeemOptionRevertsIfOptionNotBought() public {
        uint256 optionId = helperListOption();

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__OptionHasNotBeenBought
                .selector
        );
        optionsMarketplace.redeemOption(optionId);
    }

    function testRedeemOptionRevertsIfNotBuyer() public {
        uint256 optionId = helperListOption();
        helperBuyOption(optionId);

        vm.prank(seller);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__YouAreNotTheBuyerOfThisOption
                .selector
        );
        optionsMarketplace.redeemOption(optionId);
    }

    function testRedeemOptionRevertsIfExpired() public {
        uint256 optionId = helperListOption();
        helperBuyOption(optionId);

        vm.warp(expiration + 1);
        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace.OptionsMarketplace__OptionHasExpired.selector
        );
        optionsMarketplace.redeemOption(optionId);
    }

    function testRedeemOptionRevertsIfAlreadyRedeemed() public {
        uint256 optionId = helperListOption();
        helperBuyOption(optionId);

        // This redeem should go through
        vm.prank(buyer);
        optionsMarketplace.redeemOption(optionId);

        // This redeem should fail
        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__OptionAlreadyRedeemed
                .selector
        );
        optionsMarketplace.redeemOption(optionId);
    }

    // getAssetPrice reverts
    function testGetAssetPriceRevertsIfPriceIsNegative() public {
        // This test only runs on anvil beause it requires a MockV3Aggregator
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }

        MockV3Aggregator mockV3Aggregator = MockV3Aggregator(
            optionsMarketplace.getPriceFeedAddress()
        );
        int256 mockNegativePrice = -30e18;
        mockV3Aggregator.updateAnswer(mockNegativePrice);

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace
                .OptionsMarketplace__PriceFeedGaveNegativePrice
                .selector
        );
        optionsMarketplace.getAssetPrice();
    }

    // getOptionInfo reverts
    function testGetOptionInfoRevertsIfOptionDoesNotExist() public {
        uint256 invalidOptionId = 0;

        vm.prank(buyer);
        vm.expectRevert(
            OptionsMarketplace.OptionsMarketplace__OptionDoesNotExist.selector
        );
        optionsMarketplace.getOptionInfo(invalidOptionId);
    }
}
