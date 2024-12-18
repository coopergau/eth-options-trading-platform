// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Options Trading Platform
 * @author Cooper Gau
 *
 * This contract acts as a decentralized market place for on-chain options for a given asset. The Asset can be specified in
 * the constructor with any chainlink price feed, but this example uses Bitcoin priced in terms of Ether (BTC/ETH).
 */
contract OptionsMarketplace is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
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
    error OptionsMarketplace__OptionHasNotExpired();
    error OptionsMarketplace__OptionAlreadyRedeemed();
    error OptionsMarketplace__OptionUnlistFailed();
    error OptionsMarketplace__RefundExpiredOptionFailed();
    error OptionsMarketplace__OptionRedeemFailed();
    error OptionsMarketplace__LeftOverTransferFailed();

    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/
    struct Option {
        address seller;
        address buyer;
        uint256 premium; // Price in wei
        uint256 strikePrice; // Price in wei
        uint256 expiration; // Timestamp
        bool isCall;
        bool redeemed;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 internal nextOptionId = 0;
    mapping(uint256 => Option) internal options;
    AggregatorV3Interface internal immutable priceFeedInterface;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event OptionListed(uint256 optionId, Option option);
    event OptionPremiumChanged(uint256 optionId, Option option);
    event OptionUnlisted(uint256 optionId);
    event ExpiredOptionRefunded(uint256 optionId);
    event OptionBought(uint256 optionId, Option option);
    event OptionRedeemed(uint256 optionId, Option option);

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address _priceFeedId) {
        priceFeedInterface = AggregatorV3Interface(_priceFeedId);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Lists a new option for sale in the marketplace.
     * @dev The seller must send ETH equal to the strike price when calling this function.
     * @param _premium The amount the buyer must pay to purchase the option.
     * @param _strikePrice The strike price of the option (amount to be locked in escrow).
     * @param _expiration The timestamp at which the option expires.
     * @param _isCall Whether the option is a call option (true) or put option (false).
     * @return optionId The unique ID of the newly created option.
     */
    function listOption(uint256 _premium, uint256 _strikePrice, uint256 _expiration, bool _isCall)
        public
        payable
        returns (uint256)
    {
        // Checks
        if (msg.value != _strikePrice) {
            revert OptionsMarketplace__AmountSentIsNotStrikePrice();
        }
        if (block.timestamp >= _expiration) {
            revert OptionsMarketplace__ExpirationTimestampHasPassed();
        }

        // Affects
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

        // Interactions
        options[optionId] = newOption;
        emit OptionListed(optionId, newOption);

        return optionId;
    }

    /**
     * @notice Allows the seller of an option to update the premium for oe of their existing options.
     * @dev This function can only be called if the option has not yet been purchased by a buyer.
     * @param _optionId The unique ID of the option to update.
     * @param _newPremium The new premium value of the option.
     */
    function changePremium(uint256 _optionId, uint256 _newPremium) public {
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

        option.premium = _newPremium;
        emit OptionPremiumChanged(_optionId, option);
    }

    /**
     * @notice Allows a seller of an option to take down one of their listed options if it has not
     * already been bought, and get their ether back.
     * @notice This is only for options that have not expired yet. To refund expired options, users need to call the
     * refundExpiredOption function.
     * @param _optionId The unique ID of the option to update.
     */
    function unlistOption(uint256 _optionId) public nonReentrant {
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

        // Unlisting the option before sending the seller their ether back is the more secure way of organizing the function,
        // so we need to save the seller's address beforehand to use for the the ether transfer in the next step.
        address seller = option.seller;
        option.seller = address(0);

        // Send the seller their ether back
        (bool optionUnlistSuccess,) = seller.call{value: option.strikePrice}("");
        if (!optionUnlistSuccess) {
            revert OptionsMarketplace__OptionUnlistFailed();
        }

        emit OptionUnlisted(_optionId);
    }

    /**
     * @notice Allows a seller to refund the ether they initially sent with their option if the option expired before it was purchsased.
     * @notice Even though this will probably only be called by the seller of the expired option, there is no reason for that to actually be made a requirement.
     * @param _optionId The unique ID of the option to update.
     */
    function refundExpiredOption(uint256 _optionId) public nonReentrant {
        Option storage option = options[_optionId];
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        if (option.expiration >= block.timestamp) {
            revert OptionsMarketplace__OptionHasNotExpired();
        }
        if (option.redeemed == true) {
            revert OptionsMarketplace__OptionAlreadyRedeemed();
        }

        // Unlisting the option before sending the seller their ether back is the more secure way of organizing the function,
        // so we need to save the seller's address beforehand to use for the the ether transfer in the next step.
        address seller = option.seller;
        // Set the option seller address to zero to prevent this function from being called more than once for the same option.
        option.seller = address(0);

        // Send the seller their ether back
        (bool refundSuccess,) = seller.call{value: option.strikePrice}("");
        if (!refundSuccess) {
            revert OptionsMarketplace__RefundExpiredOptionFailed();
        }

        emit ExpiredOptionRefunded(_optionId);
    }

    /**
     * @notice Allows a user to buy an option that has been listed.
     * @dev Each option can only be bought once and requires the buyer to send the option premium amount when calling the function.
     * @param _optionId The unique ID of the option to update.
     */
    function buyOption(uint256 _optionId) public payable nonReentrant {
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

        (bool optionPurchaseSuccess,) = option.seller.call{value: option.premium}("");
        if (!optionPurchaseSuccess) {
            revert OptionsMarketplace__OptionPurchaseFailed();
        }

        emit OptionBought(_optionId, option);
    }

    /**
     * @notice Allows a the buyer of an option to redeem the current value of that option.
     * @dev This function can be called any time before the expiration date.
     * @param _optionId The unique ID of the option to update.
     */
    function redeemOption(uint256 _optionId) public nonReentrant {
        // Checks
        Option storage option = options[_optionId];

        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        if (option.buyer == address(0)) {
            revert OptionsMarketplace__OptionHasNotBeenBought();
        }
        if (msg.sender != option.buyer) {
            revert OptionsMarketplace__YouAreNotTheBuyerOfThisOption();
        }
        if (block.timestamp > option.expiration) {
            revert OptionsMarketplace__OptionHasExpired();
        }
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
            } else if (currentPrice - option.strikePrice >= option.strikePrice) {
                optionValue = option.strikePrice;
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
        (bool optionRedeemSuccess,) = msg.sender.call{value: optionValue}("");
        if (!optionRedeemSuccess) {
            revert OptionsMarketplace__OptionRedeemFailed();
        }
        // Send left over value back to the seller
        if (leftOverValue > 0) {
            (bool leftOverSuccess,) = option.seller.call{value: leftOverValue}("");
            if (!leftOverSuccess) {
                revert OptionsMarketplace__LeftOverTransferFailed();
            }
        }

        emit OptionRedeemed(_optionId, option);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getAssetPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeedInterface.latestRoundData();
        if (price < 0) {
            revert OptionsMarketplace__PriceFeedGaveNegativePrice();
        }
        return uint256(price);
    }

    function getOptionInfo(uint256 _optionId) external view returns (Option memory) {
        Option memory option = options[_optionId];
        if (option.seller == address(0)) {
            revert OptionsMarketplace__OptionDoesNotExist();
        }
        return options[_optionId];
    }

    function getPriceFeedAddress() external view returns (address) {
        return address(priceFeedInterface);
    }

    function getNextOptionId() external view returns (uint256) {
        return nextOptionId;
    }
}
