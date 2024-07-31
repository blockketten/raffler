
# Raffle Contract

## Overview

This repository contains a smart contract for a decentralized raffle system built on the Ethereum blockchain using Solidity. The contract leverages Chainlink VRF (Verifiable Random Function) v2.5 for random number generation to ensure fairness in selecting the raffle winner.

## Table of Contents

- [Raffle Contract](#raffle-contract)
  - [Overview](#overview)
  - [Table of Contents](#table-of-contents)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Deployment on Ethereum Sepolia](#deployment-on-ethereum-sepolia)
    - [Interactions](#interactions)
    - [Testing](#testing)
  - [Contract Details](#contract-details)
    - [Raffle Contract](#raffle-contract-1)
      - [State Variables](#state-variables)
      - [Functions](#functions)
      - [Events](#events)
  - [License](#license)

## Getting Started

These instructions will help you set up the project on your local machine for development and testing purposes.

### Prerequisites

- [Node.js](https://nodejs.org/)
- [npm](https://www.npmjs.com/)
- [Foundry](https://book.getfoundry.sh/)
- A web3 wallet, such as Metamask
- A small balance of Sepolia $ETH and $LINK: These can be acquired from faucets.

### Installation

Clone the repository and install the necessary dependencies:

```bash
git clone https://github.com/yourusername/raffle-contract.git
cd raffle-contract
make install
```

### Deployment on Ethereum Sepolia

To deploy the smart contract on Ethereum Sepolia, you need to configure environment variables and deploy the contract using Foundry.

Ideally, you would create your own Chainlink VRF subscription on Ethereum Sepolia network and add your own admin public key address and VRF subscription ID into the config file.

However, you are free to use my Chainlink subscription. If the LINK balance drops to low, shoot me a message and I will top it up.

1. Create a keystore that encrypts and stores your private key securely:

```bash
cast wallet import <keystore account name> –interactive
```

You will need to type in your private key and then a password that you must remember to decrypt the private key later.

2. Create a `.env` file in the project root and add your environment variables:

```env
SEPOLIA_RPC_URL=<Your Sepolia RPC URL>
ACCOUNT=<Your keystore account name>
ETHERSCAN_API_KEY=<Your Etherscan API Key>
```

3.  Deploy the contract the contract on Sepolia:

```bash
make deploy-sepolia
```

You will need to enter the aforementioned keystore password to complete the deployment

4. Automate upkeep of the contract (resetting the contract state for a new raffle after a previous one has completed):

Go to https://automation.chain.link/, connect your wallet, and select "Register new Upkeep".

Select "Custom Logic", click "Next", provide a name for your contract, enter an initial amount of LINK to fund the Upkeep with (there is a link to a faucet, in case you don't have any testnet LINK), and then click "Register Upkeep". Your web3 wallet will prompt you to send a transaction and sign a message. Your Upkeep is now setup and maintenance of the contract is automated. Congrats!



### Interactions

The repository contains scripts to interact with the deployed contract.

1. Create a subscription:

```bash
forge script script/CreateSubscription.s.sol:CreateSubscription --broadcast
```

2. Fund the subscription:

```bash
forge script script/FundSubscription.s.sol:FundSubscription --broadcast
```

3. Add a consumer:

```bash
forge script script/AddConsumer.s.sol:AddConsumer --broadcast
```

### Testing

To run the tests, use the following command:

```bash
forge test
```

## Contract Details

### Raffle Contract

The `Raffle` contract allows users to buy tickets and enter a raffle. The contract uses Chainlink VRF v2.5 for random number generation to ensure fairness.

#### State Variables

- `i_entranceFee`: The cost to enter the raffle.
- `i_interval`: The duration of the raffle in seconds.
- `i_keyHash`: The gas lane key hash.
- `i_subscriptionId`: The subscription ID for the VRF coordinator.
- `i_callbackGasLimit`: The gas limit for the callback.
- `s_lastTimeStamp`: The last time the raffle was run.
- `s_players`: The array of addresses of players in the raffle.
- `s_recentWinner`: The address of the most recent winner.
- `s_raffleState`: The state of the raffle (OPEN or CALCULATING).

#### Functions

- `enterRaffle`: Allows users to enter the raffle by paying the entrance fee.
- `checkUpkeep`: Checks if the raffle is ready to pick a winner.
- `performUpkeep`: Requests random words from the VRF coordinator.
- `fulfillRandomWords`: Picks a winner and transfers the prize.

#### Events

- `RaffleEntered`: Emitted when a player enters the raffle.
- `WinnerPicked`: Emitted when a winner is picked.
- `RequestedRaffleWinner`: Emitted when a random word request is made.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
