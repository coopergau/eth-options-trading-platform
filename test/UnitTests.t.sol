// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOptionsMarketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
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

    function testListOptionUpdatesBalances() public {
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

    function testListOptionUpdatesNextOptionId() public {
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

    // The following tests often use options that have been listed.
    function helperListOption(bool _isCall) internal returns (uint256) {
        vm.prank(seller);
        uint256 optionId = optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            expiration,
            _isCall
        );
        return optionId;
    }

    // changePremium tests
    function testChangePremiumChangesPremium() public {
        uint256 newPremium = PREMIUM + 1 ether;
        uint256 optionId = helperListOption(IS_CALL);

        vm.prank(seller);
        optionsMarketplace.changePremium(optionId, newPremium);

        OptionsMarketplace.Option memory option = optionsMarketplace
            .getOptionInfo(optionId);

        assertEq(option.premium, newPremium);
    }

    // buyOption tests
    function testBuyOptionUpdatesBuyerField() public {
        uint256 optionId = helperListOption(IS_CALL);

        vm.prank(buyer);
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);

        OptionsMarketplace.Option memory option = optionsMarketplace
            .getOptionInfo(optionId);

        assertEq(option.buyer, address(buyer));
    }

    // redeemOption tests
    /* To effectively test the redeemOption function with different asset prices there are tests in the FuzzTests.t.sol files. These tests require maipulation of the asset price feed so they are only run on anvil. This test is intended to ensure that the redeemOption function works correctly on the eth mainnet and sepolia testnet so it only tests with the current actualy price. */
    function testRedeemOptionCallUpdatesBalances() public {
        uint256 optionId = helperListOption(IS_CALL);
        vm.prank(buyer);
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);

        // Get initial balances
        uint256 initialSellerBalance = seller.balance;
        uint256 initialBuyerBalance = buyer.balance;
        uint256 initialContractBalance = address(optionsMarketplace).balance;

        // Theoretically this test could fail if the asset price changes in the time between the getAssetPrice call and the redeemoption call.
        uint256 currentAssetPrice = optionsMarketplace.getAssetPrice();
        vm.prank(buyer);
        optionsMarketplace.redeemOption(optionId);

        // Calculate the amounts the ETH that go to the buyer and seller
        uint256 optionValue;
        if (currentAssetPrice <= STRIKE_PRICE) {
            optionValue = 0;
        } else if (currentAssetPrice - STRIKE_PRICE >= STRIKE_PRICE) {
            optionValue = STRIKE_PRICE;
        } else {
            optionValue = currentAssetPrice - STRIKE_PRICE;
        }
        uint256 leftOverValue = STRIKE_PRICE - optionValue;

        // Get final balances
        uint256 finalSellerBalance = seller.balance;
        uint256 finalBuyerBalance = buyer.balance;
        uint256 finalContractBalance = address(optionsMarketplace).balance;

        assertEq(finalSellerBalance, initialSellerBalance + leftOverValue);
        assertEq(finalBuyerBalance, initialBuyerBalance + optionValue);
        assertEq(finalContractBalance, initialContractBalance - STRIKE_PRICE);
    }

    function testRedeemOptionPutUpdatesBalances() public {
        uint256 optionId = helperListOption(IS_PUT);
        vm.prank(buyer);
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);

        // Get initial balances
        uint256 initialSellerBalance = seller.balance;
        uint256 initialBuyerBalance = buyer.balance;
        uint256 initialContractBalance = address(optionsMarketplace).balance;

        // Theoretically this test could fail if the asset price changes in the time between the getAssetPrice call and the redeemoption call.
        uint256 currentAssetPrice = optionsMarketplace.getAssetPrice();
        vm.prank(buyer);
        optionsMarketplace.redeemOption(optionId);

        // Calculate the amounts the ETH that go to the buyer and seller
        uint256 optionValue;
        if (currentAssetPrice >= STRIKE_PRICE) {
            optionValue = 0;
        } else {
            optionValue = STRIKE_PRICE - currentAssetPrice;
        }
        uint256 leftOverValue = STRIKE_PRICE - optionValue;

        // Get final balances
        uint256 finalSellerBalance = seller.balance;
        uint256 finalBuyerBalance = buyer.balance;
        uint256 finalContractBalance = address(optionsMarketplace).balance;

        assertEq(finalSellerBalance, initialSellerBalance + leftOverValue);
        assertEq(finalBuyerBalance, initialBuyerBalance + optionValue);
        assertEq(finalContractBalance, initialContractBalance - STRIKE_PRICE);
    }

    // getAssetPrice test (only anvil)
    function testGetAssetPriceReturnsCorrectPriceWithMock() public {
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }

        MockV3Aggregator mockV3Aggregator = MockV3Aggregator(
            optionsMarketplace.getPriceFeedAddress()
        );
        int256 newAssetPrice = 20e18;
        mockV3Aggregator.updateAnswer(newAssetPrice);

        uint256 Assetprice = optionsMarketplace.getAssetPrice();

        assertEq(Assetprice, uint256(newAssetPrice));
    }
}
