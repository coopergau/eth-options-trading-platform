// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
//import {console} from "lib/forge-std/src/console.sol";

contract OptionsMarketplace {
    // Errors
    error OptionsMarketplace__AmountSentIsNotStrikePrice();
    error OptionsMarketplace__ExpirationTimestampHasPassed();
    error OptionsMarketplace__OptionDoesNotExist();
    error OptionsMarketplace__YouAreNotTheSellerOfThisOption();
    error OptionsMarketplace__YouAreNotTheBuyerOfThisOption();
    error OptionsMarketplace__OptionHasAlreadyBeenBought();
    error OptionsMarketplace__OptionHasNotBeenBought();
    error OptionsMarketplace__SentIncorrectAmountOfEth();
    error OptionsMarketplace__OptionPurchaseFailed();
    error OptionsMarketplace__PriceFeedGaveNegativePrice();
    error OptionsMarketplace__OptionHasExpired();
    error OptionsMarketplace__OptionAlreadyRedeemed();
    error OptionsMarketplace__OptionRedeemFailed();
    error OptionsMarketplace__LeftOverTransferFailed();

    // Structs
    struct Option {
        address seller;
        address buyer;
        uint256 premium; // Price in ETH
        uint256 strikePrice; // Price in ETH
        uint256 expiration; // Timestamp
        bool isCall;
        bool redeemed;
    }

    // Variables
    uint256 internal nextOptionId = 0;
    AggregatorV3Interface internal immutable priceFeed;

    // Mappings
    mapping(uint256 => Option) internal options;

    // Events
    event OptionListed(uint256 optionId, Option option);
    event OptionPriceChanged(uint256 optionId, Option option);
    event OptionBought(uint256 optionId, Option option);
    event OptionRedeemed(uint256 optionId, Option option);

    // Functions
    constructor(address _priceFeedId) {
        priceFeed = AggregatorV3Interface(_priceFeedId);
    }

    function listOption(
        uint256 _premium,
        uint256 _strikePrice,
        uint256 _expiration,
        bool _isCall
    ) public payable returns (uint256) {
        if (msg.value != _strikePrice) {
            revert OptionsMarketplace__AmountSentIsNotStrikePrice();
        }
        if (block.timestamp >= _expiration) {
            revert OptionsMarketplace__ExpirationTimestampHasPassed();
        }

        uint256 optionId = nextOptionId;
        nextOptionId++;

        Option memory newOption = Option({
            seller: msg.sender,
            buyer: address(0),
            premium: _premium,
            strikePrice: _strikePrice,
            expiration: _expiration,
            isCall: _isCall,
            redeemed: false
        });

        options[optionId] = newOption;
        emit OptionListed(optionId, newOption);

        return optionId;
    }

    function changePremium(uint256 _optionId, uint256 newPremium) public {
        Option storage option = options[_optionId];
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        if (option.seller != msg.sender) {
            revert OptionsMarketplace__YouAreNotTheSellerOfThisOption();
        }
        if (option.buyer != address(0)) {
            revert OptionsMarketplace__OptionHasAlreadyBeenBought();
        }

        option.premium = newPremium;
        emit OptionPriceChanged(_optionId, option);
    }

    function buyOption(uint256 _optionId) public payable {
        Option storage option = options[_optionId];
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        if (option.buyer != address(0)) {
            revert OptionsMarketplace__OptionHasAlreadyBeenBought();
        }
        if (msg.value != option.premium) {
            revert OptionsMarketplace__SentIncorrectAmountOfEth();
        }

        option.buyer = msg.sender;

        (bool optionPurchaseSuccess, ) = option.seller.call{
            value: option.premium
        }("");
        if (!optionPurchaseSuccess) {
            revert OptionsMarketplace__OptionPurchaseFailed();
        }
    }

    function redeemOption(uint256 _optionId) public {
        // Checks
        Option storage option = options[_optionId];
        // Check that the option exists
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        // Check that the option has been bought
        if (option.buyer == address(0)) {
            revert OptionsMarketplace__OptionHasNotBeenBought();
        }
        // Check that the function was called by the buyer
        if (msg.sender != option.buyer) {
            revert OptionsMarketplace__YouAreNotTheBuyerOfThisOption();
        }
        // Check that the expiration time has not passed
        if (block.timestamp > option.expiration) {
            revert OptionsMarketplace__OptionHasExpired();
        }
        // Check that the option has not already been redeemed
        if (option.redeemed == true) {
            revert OptionsMarketplace__OptionAlreadyRedeemed();
        }

        // Affects
        option.redeemed = true;

        // Calculate current option value and left over value
        uint256 currentPrice = getAssetPrice();
        uint256 optionValue;
        if (option.isCall) {
            if (currentPrice <= option.strikePrice) {
                optionValue = 0;
            } else {
                optionValue = currentPrice - option.strikePrice;
            }
        } else {
            if (currentPrice >= option.strikePrice) {
                optionValue = 0;
            } else {
                optionValue = option.strikePrice - currentPrice;
            }
        }
        uint256 leftOverValue = option.strikePrice - optionValue;

        // Interactions
        // Send option value to the buyer
        (bool optionRedeemSuccess, ) = msg.sender.call{value: optionValue}("");
        if (!optionRedeemSuccess) {
            revert OptionsMarketplace__OptionRedeemFailed();
        }
        // Send left over value back to the seller
        if (leftOverValue > 0) {
            (bool leftOverSuccess, ) = option.seller.call{value: leftOverValue}(
                ""
            );
            if (!leftOverSuccess) {
                revert OptionsMarketplace__LeftOverTransferFailed();
            }
        }
    }

    function getAssetPrice() internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        if (price < 0) {
            revert OptionsMarketplace__PriceFeedGaveNegativePrice();
        }
        return uint256(price);
    }

    function getOptionInfo(
        uint256 _optionId
    ) public view returns (Option memory) {
        Option memory option = options[_optionId];
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        return options[_optionId];
    }
}
