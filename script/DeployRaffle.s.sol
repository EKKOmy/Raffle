// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        HelperConfig hc = new HelperConfig();
        (
            uint256 entrancefee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            ,
            uint256 privateKey
        ) = hc.activeNetworkConfig();
        vm.startBroadcast(privateKey);
        Raffle raffle = new Raffle(entrancefee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, address(raffle));
        vm.stopBroadcast();
        return (raffle, hc);
    }
}
