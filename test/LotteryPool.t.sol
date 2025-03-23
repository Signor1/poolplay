// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
// import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/token/ERC677/LinkToken.sol";

import {LotteryPool} from "../src/LotteryPool.sol";

contract LotteryPoolTest is Test {
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    LotteryPool public lotteryPool;

    address owner = mkaddr("owner");
    address hook = address(0xff);
    LinkToken payout;

    function setUp() public {
        switchSigner(owner);
        vrfCoordinator = new VRFCoordinatorV2_5Mock(1e6, 10e6, 1e18);
        payout = new LinkToken();
        lotteryPool = new LotteryPool(address(vrfCoordinator), address(payout));

        vrfCoordinator.setLINKAndLINKNativeFeed(address(payout), address(0));

        lotteryPool.initialize(hook, 7 days, address(payout));

        payout.grantMintAndBurnRoles(owner);

        payout.mint(address(hook), 1000e18);
        payout.mint(address(lotteryPool), 10e18);
        lotteryPool.topUpSubscription(10e18);
    }

    function testLotteryPoolDepositFee() public {
        switchSigner(hook);
        payout.approve(address(lotteryPool), 100e18);
        lotteryPool.depositFee(100e18);
        assertEq(payout.balanceOf(address(lotteryPool)), 100e18);
    }

    function testRecordLiquidity() public {
        _depositFee(100e18);
        for (uint256 i = 0; i < 10; i++) {
            address addr = mkaddr(string(abi.encode(i)));
            lotteryPool.recordLiquidity(addr, 100e18 / (i + 1));
        }
        uint256 epoch = lotteryPool.currentEpoch();
        (
            uint40 startTime,
            uint40 endTime,
            uint256 totalFees,
            ,
            address[] memory participants
        ) = lotteryPool.getEpochDetails(epoch);

        assertEq(participants.length, 10);
        assertEq(totalFees, 100e18);
        assertEq((endTime - startTime), 7 days);
    }

    function testWinnerSelection() public {
        _depositFee(100e18);
        for (uint256 i = 0; i < 10; i++) {
            address addr = mkaddr(string(abi.encode(i)));
            lotteryPool.recordLiquidity(addr, 100e18 / (i + 1));
        }
        vm.warp(block.timestamp + 7 days);
        lotteryPool.updateLiquidity();

        address winnerAddress = mkaddr(string(abi.encode(1)));
        uint256 balanceBefore = payout.balanceOf(winnerAddress);

        uint256[] memory overrideValues = new uint256[](1);
        overrideValues[0] = 1;

        vrfCoordinator.fulfillRandomWordsWithOverride(
            1,
            address(lotteryPool),
            overrideValues
        );

        uint256 balanceAfter = payout.balanceOf(winnerAddress);

        uint256 epoch = lotteryPool.currentEpoch() - 1;
        (, , , address winner, ) = lotteryPool.getEpochDetails(epoch);
        assertNotEq(winner, address(0));
        assertEq(balanceAfter - balanceBefore, 90e18);
    }

    function testRecordLiquidityStartsNewEpochWhenTimeElapses() public {
        _depositFee(100e18);
        for (uint256 i = 0; i < 10; i++) {
            vm.warp(block.timestamp + 1 days);
            address addr = mkaddr(string(abi.encode(i)));
            lotteryPool.recordLiquidity(addr, 100e18 / (i + 1));
        }
        uint256 epoch = lotteryPool.currentEpoch();
        (
            uint40 startTime,
            uint40 endTime,
            uint256 totalFees,
            ,
            address[] memory participants
        ) = lotteryPool.getEpochDetails(epoch);

        assertEq(participants.length, 4);
        assertEq(totalFees, 0);
        assertEq((endTime - startTime), 7 days);
    }

    function _depositFee(uint256 _amount) public {
        switchSigner(hook);
        payout.approve(address(lotteryPool), _amount);
        lotteryPool.depositFee(_amount);
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }
}
