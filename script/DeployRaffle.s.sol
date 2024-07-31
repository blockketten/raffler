// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    // Function to deploy the Raffle contract and set up VRF subscription
    function run() public returns (Raffle, HelperConfig) {
        // Create an instance of HelperConfig to get network-specific configurations
        HelperConfig helperConfig = new HelperConfig();
        // Retrieve the network configuration
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // If the subscriptionId is zero, create and fund a new Chainlink VRF subscription
        if (config.subscriptionId == 0) {
            // Create a new subscription
            CreateSubscription createSubscription = new CreateSubscription();
            // Create the subscription and retrieve the subscriptionId and vrfCoordinator address
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            // Fund the newly created subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator, // Address of the VRF Coordinator
                config.subscriptionId, // The subscription ID
                config.link, // Amount of LINK to fund the subscription with
                config.account // The account that will fund the subscription
            );
        }

        // Start broadcasting transactions from the specified account
        vm.startBroadcast(config.account);

        // Deploy the Raffle contract with the retrieved configurations
        Raffle raffle = new Raffle(
            config.entranceFee, // The entrance fee for the raffle
            config.interval, // The duration of the raffle
            config.vrfCoordinator, // The VRF Coordinator address
            config.gasLane, // The key hash for the VRF
            config.subscriptionId, // The subscription ID for VRF
            config.callbackGasLimit // The gas limit for the VRF callback
        );

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Add the Raffle contract as a consumer of the VRF subscription
        AddConsumer addConsumer = new AddConsumer();
        // Call the addConsumer function to register the Raffle contract with the subscription
        // Broadcasting is handled within the addConsumer function
        addConsumer.addConsumer(
            address(raffle), // The address of the Raffle contract
            config.vrfCoordinator, // The VRF Coordinator address
            config.subscriptionId, // The subscription ID
            config.account // The account that owns the subscription
        );

        // Return the deployed Raffle contract and the helper configuration
        return (raffle, helperConfig);
    }
}
