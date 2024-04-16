// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entrancefee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else {
            activeNetworkConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entrancefee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 10696,
            callbackGasLimit: 500_000
        });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        uint96 _baseFee = 0.25 ether;
        uint96 _gasPriceLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(_baseFee, _gasPriceLink);
        uint64 subscriptionId = vrfCoordinatorV2Mock.createSubscription();
        vrfCoordinatorV2Mock.fundSubscription(subscriptionId, 100 ether);
        vm.stopBroadcast();

        return NetworkConfig({
            entrancefee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: subscriptionId,
            callbackGasLimit: 500_000
        });
    }
}
