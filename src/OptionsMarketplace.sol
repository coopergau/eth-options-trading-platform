// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

contract OptionsMarketplace {
    // Errors
    error OptionsMarketplace__AmountSentIsNotStrikePrice();
    error OptionsMarketplace__ExpirationTimestampHasPassed();
    error OptionsMarketplace__SubmittedAssetIsNotValid();

    // Structs
    struct Option {
        address seller;
        address buyer;
        string asset; // Make this correspond with what the oracle uses
        uint256 optionPrice; // Price in ether
        uint256 strikePrice; // Price in ether
        uint256 expiration; // Timestamp
        bool isCall;
    }

    // Variables
    uint256 internal nextOptionId;

    // Mappings
    mapping(uint256 => Option) internal options;
    mapping(string => bool) internal isValidAsset;

    // Events
    event OptionListed(uint256 optionId, Option option);
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
            isCall: _isCall
        });
    }

    function changePrice() public {}
    function buyOption() public {}
    function redeemOption() public {}
    function getOptionStatus() public {}
}
