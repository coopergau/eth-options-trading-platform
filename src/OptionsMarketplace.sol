// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract OptionsMarketplace {
    // Errors
    error OptionsMarketplace__AmountSentIsNotStrikePrice();
    error OptionsMarketplace__ExpirationTimestampHasPassed();
    error OptionsMarketplace__SubmittedAssetIsNotValid();
    error OptionsMarketplace__OptionDoesNotExist();
    error OptionsMarketplace__YouAreNotTheSellerOfThisOption();
    error OptionsMarketplace__OptionHasAlreadyBeenBought();
    error OptionsMarketplace__SentIncorrectAmountOfEth();
    error OptionsMarketplace__OptionPurchaseFailed();

    // Structs
    struct Option {
        address seller;
        address buyer;
        string asset; // Make this correspond with what the oracle uses
        uint256 optionPrice; // Price in ether
        uint256 strikePrice; // Price in ether
        uint256 expiration; // Timestamp
        bool isCall;
        bool redeemed;
    }

    // Variables
    uint256 internal nextOptionId;

    // Mappings
    mapping(uint256 => Option) internal options;
    mapping(string => bool) internal isValidAsset;

    // Events
    event OptionListed(uint256 optionId, Option option);
    event OptionPriceChanged(uint256 optionId, Option option);
    event OptionBought(uint256 optionId, Option option);
    event OptionRedeemed(uint256 optionId, Option option);

    // Functions
    constructor(string[] memory validAssets) {
        for (uint256 i = 0; i < validAssets.length; i++) {
            isValidAsset[validAssets[i]] = true;
        }
    }

    function listOption(
        string calldata _asset,
        uint256 _optionPrice,
        uint256 _strikePrice,
        uint256 _expiration,
        bool _isCall
    ) public payable {
        if (msg.value / 1 ether != _strikePrice) {
            revert OptionsMarketplace__AmountSentIsNotStrikePrice();
        }
        if (block.timestamp >= _expiration) {
            revert OptionsMarketplace__ExpirationTimestampHasPassed();
        }
        if (!isValidAsset[_asset]) {
            revert OptionsMarketplace__SubmittedAssetIsNotValid();
        }

        options[nextOptionId] = Option({
            seller: msg.sender,
            buyer: address(0),
            asset: _asset,
            optionPrice: _optionPrice,
            strikePrice: _strikePrice,
            expiration: _expiration,
            isCall: _isCall,
            redeemed: false
        });

        emit OptionListed(nextOptionId, options[nextOptionId]);

        nextOptionId++;
    }

    function changePrice(uint256 _optionId, uint256 newPrice) public {
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

        option.optionPrice = newPrice;
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
        if (msg.value != option.optionPrice) {
            revert OptionsMarketplace__SentIncorrectAmountOfEth();
        }

        option.buyer = msg.sender;

        (bool optionPurchaseSuccess, ) = msg.sender.call{
            value: option.optionPrice
        }("");
        if (!optionPurchaseSuccess) {
            revert OptionsMarketplace__OptionPurchaseFailed();
        }
    }

    function redeemOption() public {}

    function getOptionInfo(
        uint256 _optionId
    ) public view returns (Option memory) {
        return options[_optionId];
    }
}
