// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOptionsMarketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
// import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {console} from "lib/forge-std/src/console.sol";

// Should I put info here?
contract UnitTests is Test {
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
    bool public constant IS_PUT = false;
    bool public constant NOT_REDEEMED = false;
    bool public constant REDEEMED = true;

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

    // listOption tests
    function testListOptionListsWithRightInfo() public {
        uint256 firstOptionId = optionsMarketplace.getNextOptionId();
        vm.prank(seller);
        optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );

        OptionsMarketplace.Option memory option = optionsMarketplace
            .getOptionInfo(firstOptionId);

        assertEq(option.seller, seller);
        assertEq(option.buyer, address(0));
        assertEq(option.premium, PREMIUM);
        assertEq(option.strikePrice, STRIKE_PRICE);
        assertEq(option.expiration, expiration);
        assertEq(option.isCall, IS_CALL);
        assertEq(option.redeemed, NOT_REDEEMED);
    }

    function testListOptionUpatesBalances() public {
        uint256 initialSellerBalance = seller.balance;
        uint256 initialContractBalance = address(optionsMarketplace).balance;

        vm.prank(seller);
        optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );

        uint256 finalSellerBalance = seller.balance;
        uint256 finalContractBalance = address(optionsMarketplace).balance;

        assertEq(finalSellerBalance, initialSellerBalance - STRIKE_PRICE);
        assertEq(finalContractBalance, initialContractBalance + STRIKE_PRICE);
    }

    function testListOptionUpatesNextOptionId() public {
        uint256 initialNextOptionId = optionsMarketplace.getNextOptionId();

        vm.prank(seller);
        optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );

        uint256 finalNextOptionId = optionsMarketplace.getNextOptionId();

        assertEq(finalNextOptionId, initialNextOptionId + 1);
    }

    function testListOptionEmitsEvent() public {
        uint256 firstOptionId = optionsMarketplace.getNextOptionId();
        OptionsMarketplace.Option memory expectedOption = OptionsMarketplace
            .Option({
                seller: seller,
                buyer: address(0),
                premium: PREMIUM,
                strikePrice: STRIKE_PRICE,
                expiration: expiration,
                isCall: IS_CALL,
                redeemed: NOT_REDEEMED
            });

        vm.expectEmit();
        emit OptionsMarketplace.OptionListed(firstOptionId, expectedOption);
        vm.prank(seller);
        optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            IS_CALL
        );
    }

    // changePremium tests

    // buyOption tests

    // redeemOption tests

    // getAssetPrice test (only anvil)
}
