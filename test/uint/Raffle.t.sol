// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;
    uint256 entrancefee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address USER = makeAddr("user");

    event EnteredRaffle(address indexed player);

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (entrancefee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit) =
            helperConfig.activeNetworkConfig();
        vm.deal(USER, 1 ether);
        vm.prank(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, address(raffle));
    }

    function testStartRaffleState() external {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testPayNotEnough() external {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__NotEnoughethSend.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testPlayerPush() external {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.01 ether}();
        address expectUser = raffle.getPlayers()[0];
        assert(USER == expectUser);
    }

    function testEnterRaffleEvent() external {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(USER);
        raffle.enterRaffle{value: 0.01 ether}();
    }

    function testEnterInCalculating() external {
        console.log(address(helperConfig));
        console.log(address(raffle));
        console.log(msg.sender);
        console.log(USER);
        // 0x104fBc016F4bb334D775a19E8A6510109AC63E00
        //   0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76
        //   0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        //   0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D

        vm.startPrank(USER);
        raffle.enterRaffle{value: 0.01 ether}();
        vm.warp(block.timestamp + interval + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        raffle.enterRaffle{value: 0.01 ether}();
        vm.stopPrank();
    }

    function testCheckUpKeepNoBalance() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool success,) = raffle.checkUpkeep("");
        assert(!success);
    }

    function testCheckUpKeepNotOpen() external {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool success,) = raffle.checkUpkeep("");
        assert(!success);
    }

    function testFailPerformUpKeepIsTrue() external {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.1 ether}();
        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);
        raffle.performUpkeep("");
    }

    function testFailRecordLog() external {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.1 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        assert(requestId > 0);
    }

    function testAfterPerformUpKeep(uint256 requestId) external {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }
}
