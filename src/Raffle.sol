//  SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @notice This contract is a raffle contract that allows users to buy tickets and enter a raffle
 * @dev Implements Chainlink VRFv2.5 for random number selection.
 * @dev Chainlink Automation (Keepers) automates the calling of "upkeep" functions.
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Type Declarations */
    // Enum to represent the state of the raffle
    enum RaffleState {
        OPEN, //0 Raffle is open and accepting entries
        CALCULATING //1 Winner is being selected
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // Number of confirmations for the VRF request
    uint32 private constant NUM_WORDS = 1; // Number of random words requested from VRF
    uint256 private immutable i_entranceFee; // Entrance fee for the raffle
    uint256 private immutable i_interval; // Duration of the raffle in seconds
    bytes32 private immutable i_keyHash; // Key hash for VRF
    uint256 private immutable i_subscriptionId; // Subscription ID for VRF
    uint32 private immutable i_callbackGasLimit; // Gas limit for the callback function
    uint256 private s_lastTimeStamp; // Last time the raffle was run
    address payable[] private s_players; // Array of players in the raffle, need to be payable to receive ETH
    address private s_recentWinner; // Address of the most recent winner
    RaffleState private s_raffleState; // Current state of the raffle

    /* Events */
    event RaffleEntered(address indexed player); // Event emitted when a player enters the raffle
    event WinnerPicked(address indexed winner); // Event emitted when a winner is picked
    event RequestedRaffleWinner(uint256 indexed requestId); // Event emitted when a VRF request is made

    /* Errors */
    error Raffle__NotEnoughEthSentToEnterRaffle(); // Error when not enough ETH is sent to enter the raffle
    error Raffle__TransferFailed(); // Error when ETH transfer fails
    error Raffle__RaffleNotOpen(); // Error when the raffle is not open
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    ); // Error when upkeep is not needed

    /* Modifiers */

    // No modifiers in this contract

    /* Functions */

    /**
     * @notice Constructor to initialize the raffle contract
     * @param entranceFee The entrance fee for the raffle
     * @param interval The duration of the raffle in seconds
     * @param vrfCoordinator The address of the VRF Coordinator
     * @param gasLane The key hash for the VRF
     * @param subscriptionId The subscription ID for the VRF
     * @param callbackGasLimit The gas limit for the callback function
     */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp; // Set the initial timestamp to the current block timestamp
        s_raffleState = RaffleState.OPEN; // Initialize the raffle state to OPEN
    }

    /**
     * @notice Allows users to enter the raffle by paying the entrance fee
     */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSentToEnterRaffle(); // Check if the sent value is less than the entrance fee
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen(); // Check if the raffle is open
        }

        s_players.push(payable(msg.sender)); // Add the player to the array
        emit RaffleEntered(msg.sender); // Emit the RaffleEntered event
    }

    /**
     * @notice Function to check if the upkeep is needed (called by Chainlink Keepers)
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; // Check if the interval has passed
        bool isOpen = (s_raffleState == RaffleState.OPEN); // Check if the raffle is open
        bool hasBalance = address(this).balance > 0; // Check if the contract has balance
        bool hasPlayers = s_players.length > 0; // Check if there are players in the raffle
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers; // All conditions must be true for upkeep to be needed
        return (upkeepNeeded, "");
    }

    /**
     * @notice Function to perform the upkeep (called by Chainlink Keepers)
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING; // Set the raffle state to CALCULATING

        // Create a VRF request for random words
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId); // Emit the RequestedRaffleWinner event
    }

    /**
     * @notice Callback function used by Chainlink VRF to return the random number
     * @param requestId The request ID of the VRF request
     * @param randomWords The array of random words returned by VRF
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length; // Calculate the index of the winner
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN; // Reset the raffle state to OPEN
        s_players = new address payable[](0); // Reset the players array
        s_lastTimeStamp = block.timestamp; // Reset the last timestamp
        emit WinnerPicked(s_recentWinner); // Emit the WinnerPicked event

        (bool success, ) = recentWinner.call{value: address(this).balance}(""); // Transfer the prize pool to the winner
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // Getter functions for private variables

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
