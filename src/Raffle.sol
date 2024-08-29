/* Layout of the contract file: */

/* Inside Contract: */

/* Layout of Functions: */
/* constructor */
/* receive function (if exists) */
/* fallback function (if exists) */
/* external */
/* public */
/* internal */
/* private */
/* internal & private view & pure functions */
/* external & public view & pure functions */

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/* imports */
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/* interfaces, libraries, contract */

/**
 * @title A sample Raffle Contract
 * @author Prowler
 * @notice This contract is for creating a sample Raffle
 * @dev Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* errors */
    error Raffle__NotEnoughETHSent();
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_EntranceFee;
    uint256 private immutable i_Interval; // @dev Duration of Lottery in Seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint256 private s_LastTimeStamp;
    address payable[] private s_Players;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    /* Modifiers */
    /* Functions */
    constructor(
        uint256 EntranceFee,
        uint256 Interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_EntranceFee = EntranceFee;
        i_Interval = Interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_LastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_EntranceFee, "Not Enough ETH Sent");  // Not very Gas Efficient Because we are storing the string onto the memory
        // require(msg.value >= i_EntranceFee, Raffle__NotEnoughETHSent());  Can be used in newer versions of solidity when compiled with via-ir compiler
        if (msg.value < i_EntranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        s_Players.push(payable(msg.sender));
        /* Why use Events?
            1. Makes Migration easier
            2. Makes Front-end "indexing" easier
        */
        emit RaffleEntered(msg.sender);
    }

    // Get a random number
    // Use a random number to pick a player
    // Be automatically called

    function pickWinner() external {
        // Check to see if enough time has passed
        if ((block.timestamp - s_LastTimeStamp) < i_Interval) {
            revert Raffle__NotEnoughTimePassed();
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        uint256 IndexOfWinner = randomWords[0] % s_Players.length;
        address payable recentWinner = s_Players[IndexOfWinner];

        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_Players = new address payable[](0);
        s_LastTimeStamp = block.timestamp;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(s_recentWinner);
    }

    /* Getter Functions */

    function getEntranceFee() external view returns (uint256) {
        return i_EntranceFee;
    }
}
