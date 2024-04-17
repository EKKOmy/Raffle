// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {VRFCoordinatorV2Interface} from
    "@chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink-brownie-contracts/contracts/src/v0.8/AutomationCompatible.sol";

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle__NotEnoughethSend();
    error Raffle__TransferFailed();
    error Raffle__NotOpen();
    error Raffle__UpKeepNotneed(uint256 timePast, RaffleState state, uint256 balance);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFERMATIONS = 3;
    uint32 private constant REQUEST_NUMBER_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address payable private s_winner;
    RaffleState private s_raffleState;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestWinner(uint256 requestId);

    constructor(
        uint256 entrancefee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entrancefee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughethSend();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
     * VRFConsumerBaseV2
     */
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] memory randomWords) internal override {
        s_winner = s_players[randomWords[0] % s_players.length];
        s_raffleState = RaffleState.OPEN;
        delete s_players;
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_winner);
        (bool success,) = s_winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * AutomationCompatibleInterface
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        upkeepNeeded = (
            (block.timestamp - s_lastTimeStamp) > i_interval && s_raffleState == RaffleState.OPEN
                && address(this).balance > 0 && s_players.length > 0
        );
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */ ) external override {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotneed(block.timestamp - s_lastTimeStamp, s_raffleState, address(this).balance);
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFERMATIONS, i_callbackGasLimit, REQUEST_NUMBER_WORDS
        );
        emit RequestWinner(requestId);
    }

    /**
     * Getter Function
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_winner;
    }
}
