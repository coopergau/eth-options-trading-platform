# Ethereum Options Trading Platform

## Description
This project allows users to list call and put options on chain to then be bought by other users. The contract is setup so each deployment allows for the trading of options for one asset, but could easily be modified to allow for multiple asset options to be traded under one contract. For this demonstration the options are for Bitcoin. The options don't actually give users the literal option to buy or sell any bitcoin but instead allow users to redeem the value of the options on chain. The Chainlink oracle network is used to get the price of Bitcoin in terms of ETH. All purchasing and redeeming of options are done using ETH. The options are similar to American style such that they can be redeemed at anytime before or at the expiration timestamp.

## Put Options
When users list a put option they are required to send the strike price amount in ETH to the smart contract. When the option is redeemed the value of the option gets sent to the user that purchased the option, the rest of the ETH gets sent back to the option seller. For exmaple, if a put option has a strike price of 0.20 ETH, the seller sends 0.20 ETH when they list the option. If the option is bought and redeemed and the asset price is 0.15 ETH, the user that bought the option gets 0.20 ETH - 0.15 ETH = 0.05 ETH and the extra 0.15 ETH goes back to the seller. If the asset price is higher than the strike price, the seller gets the entire 0.20 ETH back.

## Call Options
When users list a call option there is no way for them to send enough funds to ensure the future value of the option is covered because where put options are bounded by the asset price going to zero, call options are theoretically unbounded because there is no limit to how high the asset price can go. A practical solution to this is to limit the value a user can redeem an option for to 100% of the strike price, the same as with put options. This means that if the price of the asset increases by more than 100%, the user will not get any additional returns. For example, if a call option has a strike price of 0.20 ETH, the seller sends 0.20 ETH when they list the option. If the option is bought and redeemed and the asset price is 0.25 ETH, the user that bought the option gets 0.25 ETH - 0.20 ETH = 0.05 ETH. However, if the asset price is 0.45 ETH, this would normally mean the user who bought the option would get 0.45 ETH - 0.20 ETH = 0.25 ETH, but because we are capping the redeemable value to 100% of the strike price, the user will only receive 0.20 ETH.

## To Do
- make sure order of stuff is checks effects (Including events I think) and interactions
- add non reentrants
