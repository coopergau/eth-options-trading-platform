# Ethereum Options Trading Platform

## Overview
This project allows users to list call and put options on the Ethereum blockchain to then be bought by other users. The contract is setup so each deployment allows for the trading of options for one asset, but could easily be modified to allow for multiple asset options to be traded under one contract. For this demonstration the options are for Bitcoin. The options don't actually give users the literal option to buy or sell any bitcoin but instead allow users to redeem the value of the options on chain. The Chainlink oracle network is used to get the price of Bitcoin in terms of ETH. All purchasing and redeeming of options are done using ETH. The options are similar to American style such that they can be redeemed at anytime before or at the expiration timestamp.

## Put Options
When users list a put option they are required to send the strike price amount in ETH to the smart contract. When the option is redeemed the value of the option gets sent to the user that purchased the option, the rest of the ETH gets sent back to the option seller. For exmaple, if a put option has a strike price of 20 ETH, the seller sends 20 ETH when they list the option. If the option is bought and redeemed and the asset price is 15 ETH, the user that bought the option gets 20 ETH - 15 ETH = 5 ETH and the extra 15 ETH goes back to the seller. If the asset price is higher than the strike price, the seller gets the entire 20 ETH back.

## Call Options
When users list a call option there is no way for them to send enough funds to ensure the future value of the option is covered because where put options are bounded by the asset price going to zero, call options are theoretically unbounded because there is no limit to how high the asset price can go. A practical solution to this is to limit the value a user can redeem an option for to 100% of the strike price, the same as with put options. This means that if the price of the asset increases by more than 100%, the user will not get any additional returns. For example, if a call option has a strike price of 20 ETH, the seller sends 20 ETH when they list the option. If the option is bought and redeemed and the asset price is 25 ETH, the user that bought the option gets 25 ETH - 20 ETH = 5 ETH. However, if the asset price is 45 ETH, this would normally mean the user who bought the option would get 45 ETH - 20 ETH = 25 ETH, but because we are limiting the redeemable value to 100% of the strike price, the user will only receive 20 ETH.

# Getting Started
## Requirements
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
    - The Smart contract, deploy scripts, and tests are all written using foundry.
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
    - To clone the repository.

## Installation
Follow these steps to set up the project locally:
```bash
# Clone the repository
git clone https://github.com/coopergau/eth-options-trading-platform
cd eth-options-trading-platform

# Install dependencies
forge install

# Compile the contracts
forge build
```

## Testing
Follow these steps to run the smart contract tests locally:
```bash
# Run all tests
forge test

# Run specific tests
forge test --match-test testName
```

The helperConfig.s.sol script enables seamless testing on forked networks, specifically the Sepolia testnet and Ethereum mainnet. To test on either network, you'll need a valid RPC URL. You can obtain one from [Alchemy](https://www.alchemy.com/) or any other RPC provider.
```bash
# Simulate running the tests on the Sepolia Testnet
forge test --fork-url <Sepolia_RPC_URL>

# Simulate running the tests on the Ethereum Mainnet
forge test --fork-url <Ethereum_RPC_URL>
```

## Deployment
This project is meant to demonstrate an understanding and ability of smart contract development and should not be deployed to a mainnet but these are the steps of how that would be done:
```bash
# Deploy to a local anvil network
anvil
forge script script/DeployOptionsMarketplace.s.sol

# Deploy to specific network 
forge script script/DeployOptionsMarketplace.s.sol --rpc-url <Network_RPC_URL> --private-key <Your_Private_Key>
```

## Project Structure
The main folders of interest are:
- src/:
    - The smart contract that acts as a decentralized opions market place
- script/:
    - The deploy script and helper config script to handle deploying to different networks.
- test/:
    - The smart contract tests. Organized into three sections:
        - Unit tests: Test the smart contract functions as intended in valid situations.
        - Revert tests: Test the smart contract recognizes invalid situations and reverts when expected.
        - Fuzz tests: Test the options redeeming function works as intended over a random sample of asset prices.