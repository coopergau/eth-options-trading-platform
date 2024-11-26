// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOptionsMarketplace} from "../script/DeployOptionsMarketplace.s.sol";
import {OptionsMarketplace} from "../src/OptionsMarketplace.sol";
import {MockV3Aggregator} from "../lib/chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {console} from "../lib/forge-std/src/console.sol";

// Function Unit Tests
contract UnitTests is Test {
    OptionsMarketplace public optionsMarketplace;
    address public constant SELLER = address(1);
    address public constant BUYER = address(2);
    uint256 public constant STARTING_BALANCE = 100 ether;

    // Variables for listing valid option
    uint256 public constant EXPIRATION = 3600; // In one hour
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
        vm.deal(SELLER, STARTING_BALANCE);
        vm.deal(BUYER, STARTING_BALANCE);
    }

    function helperListOption(bool _isCall) internal returns (uint256) {
        vm.prank(SELLER);
        uint256 optionId = optionsMarketplace.listOption{value: STRIKE_PRICE}(
            PREMIUM,
            STRIKE_PRICE,
            EXPIRATION,
            _isCall
        );
        return optionId;
    }

    /* Even though the real price feed returns an int256, both of these functions get tested with random unit256 values 
    for the price because the tests are intended to test different valid prices. A negative price would cause an
    error which is tested for in Reverts.t.sol. */

    function testFuzzRedeemOptionCallUpdatesBalances(
        uint256 _assetPrice
    ) public {
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }

        // This tests prices for the asset price being anywhere from 0 to 1 trillion ether (1 trillion ether is 10^9 * 10^18 = 10^27 in wei).
        vm.assume(_assetPrice <= 1e27);

        uint256 optionId = helperListOption(IS_CALL);
        vm.prank(BUYER);
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);

        // Get initial balances
        uint256 initialSellerBalance = SELLER.balance;
        uint256 initialBuyerBalance = BUYER.balance;
        uint256 initialContractBalance = address(optionsMarketplace).balance;

        // Change the asset price
        MockV3Aggregator mockV3Aggregator = MockV3Aggregator(
            optionsMarketplace.getPriceFeedAddress()
        );
        mockV3Aggregator.updateAnswer(int256(_assetPrice));

        // Redeem the option
        console.log(_assetPrice);
        uint256 currentAssetPrice = optionsMarketplace.getAssetPrice();
        vm.prank(BUYER);
        optionsMarketplace.redeemOption(optionId);

        // Calculate the amounts the ETH that go to the BUYER and SELLER
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
        uint256 finalSellerBalance = SELLER.balance;
        uint256 finalBuyerBalance = BUYER.balance;
        uint256 finalContractBalance = address(optionsMarketplace).balance;

        assertEq(finalSellerBalance, initialSellerBalance + leftOverValue);
        assertEq(finalBuyerBalance, initialBuyerBalance + optionValue);
        assertEq(finalContractBalance, initialContractBalance - STRIKE_PRICE);
    }

    function testFuzzRedeemOptionPutUpdatesBalances(
        uint256 _assetPrice
    ) public {
        if (block.chainid != ANVIL_CHAIN_ID) {
            return;
        }

        // This tests prices for the asset price being anywhere from 0 to 1 trillion ether (1 trillion ether is 10^9 * 10^18 = 10^27 in wei).
        vm.assume(_assetPrice <= 1e27);

        uint256 optionId = helperListOption(IS_PUT);
        vm.prank(BUYER);
        optionsMarketplace.buyOption{value: PREMIUM}(optionId);

        // Get initial balances
        uint256 initialSellerBalance = SELLER.balance;
        uint256 initialBuyerBalance = BUYER.balance;
        uint256 initialContractBalance = address(optionsMarketplace).balance;

        // Change the asset price
        MockV3Aggregator mockV3Aggregator = MockV3Aggregator(
            optionsMarketplace.getPriceFeedAddress()
        );
        mockV3Aggregator.updateAnswer(int256(_assetPrice));

        // Redeem the option
        uint256 currentAssetPrice = optionsMarketplace.getAssetPrice();
        vm.prank(BUYER);
        optionsMarketplace.redeemOption(optionId);

        // Calculate the amounts the ETH that go to the BUYER and SELLER
        uint256 optionValue;
        if (currentAssetPrice >= STRIKE_PRICE) {
            optionValue = 0;
        } else {
            optionValue = STRIKE_PRICE - currentAssetPrice;
        }
        uint256 leftOverValue = STRIKE_PRICE - optionValue;

        // Get final balances
        uint256 finalSellerBalance = SELLER.balance;
        uint256 finalBuyerBalance = BUYER.balance;
        uint256 finalContractBalance = address(optionsMarketplace).balance;

        assertEq(finalSellerBalance, initialSellerBalance + leftOverValue);
        assertEq(finalBuyerBalance, initialBuyerBalance + optionValue);
        assertEq(finalContractBalance, initialContractBalance - STRIKE_PRICE);
    }
}
