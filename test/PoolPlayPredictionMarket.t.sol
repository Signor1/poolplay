// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {PoolPlayPredictionMarket} from "../src/PredictionMarket.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolPlayHook} from "./mocks/MockPoolPlayHook.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

contract PoolPlayPredictionMarketTest is Test {
    PoolPlayPredictionMarket public market;
    MockERC20 public bettingToken;
    MockPoolPlayHook public hook;
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    PoolId public poolId;

    // Events from the contract for testing
    event MarketCreated(
        uint256 indexed marketId,
        string title,
        PoolPlayPredictionMarket.PredictionType predictionType
    );
    event PredictionPlaced(
        uint256 indexed predictionId,
        uint256 indexed marketId,
        address user,
        uint256 betAmount
    );
    event PredictionSettled(
        uint256 indexed predictionId,
        PoolPlayPredictionMarket.PredictionOutcome outcome,
        uint256 potentialPayout
    );
    event MarketSettled(
        uint256 indexed marketId,
        uint256 actualValue,
        uint256 winnerCount
    );
    event PredictionWithdrawn(
        uint256 indexed predictionId,
        address user,
        uint256 amount
    );
    event MarketUpdated(uint256 indexed marketId, bool isActive);

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        vm.startPrank(owner);

        // Deploy mock contracts
        bettingToken = new MockERC20("Betting Token", "BET", 18);
        hook = new MockPoolPlayHook();

        // Deploy main contract
        market = new PoolPlayPredictionMarket(
            address(hook),
            address(bettingToken)
        );

        // Setup initial token balances
        bettingToken.mint(user1, 1000 ether);
        bettingToken.mint(user2, 1000 ether);
        bettingToken.mint(user3, 1000 ether);

        vm.stopPrank();

        // Setup approvals
        vm.prank(user1);
        bettingToken.approve(address(market), type(uint256).max);
        vm.prank(user2);
        bettingToken.approve(address(market), type(uint256).max);
        vm.prank(user3);
        bettingToken.approve(address(market), type(uint256).max);

        // Create a sample poolId
        poolId = PoolId.wrap(bytes32(uint256(1)));
    }

    // Helper function to create a market
    function createTestMarket() public returns (uint256) {
        vm.startPrank(owner);
        uint256 marketId = market.nextMarketId();

        market.createMarket(
            "Test Market",
            "Test Description",
            PoolPlayPredictionMarket.PredictionType.TVL,
            poolId,
            block.timestamp + 1 days,
            1 ether, // minBetAmount
            100 ether, // maxBetAmount
            50 // 0.5% platform fee
        );

        vm.stopPrank();
        return marketId;
    }

    // Helper function to place a prediction
    function placePrediction(
        uint256 marketId,
        address user,
        PoolPlayPredictionMarket.ComparisonType compType,
        uint256 targetValue,
        uint256 targetValue2,
        uint256 betAmount
    ) public returns (uint256) {
        vm.startPrank(user);
        uint256 predictionId = market.nextPredictionId();

        market.placePrediction(
            marketId,
            compType,
            targetValue,
            targetValue2,
            betAmount
        );

        vm.stopPrank();

        return predictionId;
    }

    // ===== Market Creation Tests =====
    function test_CreateMarket() public {
        uint256 marketId = market.nextMarketId();

        vm.expectEmit(true, false, false, true);
        emit MarketCreated(
            marketId,
            "Test Market",
            PoolPlayPredictionMarket.PredictionType.TVL
        );

        marketId = createTestMarket();

        PoolPlayPredictionMarket.Market memory createdMarket = market.getMarket(
            marketId
        );
        assertEq(createdMarket.creator, owner);
        assertEq(createdMarket.isActive, true);
        assertEq(createdMarket.isSettled, false);
    }

    function testFail_CreateMarket_NonOwner() public {
        vm.prank(user1);
        createTestMarket();
    }

    function testFail_CreateMarket_InvalidFee() public {
        vm.startPrank(owner);
        market.createMarket(
            "Test Market",
            "Test Description",
            PoolPlayPredictionMarket.PredictionType.TVL,
            poolId,
            block.timestamp + 1 days,
            1 ether,
            100 ether,
            1001 // > MAX_PLATFORM_FEE (1000)
        );
        vm.stopPrank();
    }

    // ===== Prediction Placement Tests =====
    function test_PlacePrediction() public {
        uint256 marketId = createTestMarket();
        uint256 betAmount = 5 ether;

        uint256 predictionId = market.nextPredictionId();

        vm.expectEmit(true, true, false, true);
        emit PredictionPlaced(predictionId, marketId, user1, betAmount);

        placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            betAmount
        );

        (
            ,
            address user,
            ,
            ,
            ,
            ,
            uint256 actualBetAmount,
            ,
            ,
            PoolPlayPredictionMarket.PredictionOutcome outcome,
            ,
            ,

        ) = market.predictions(predictionId);

        assertEq(user, user1);
        assertEq(actualBetAmount, betAmount);
        assertEq(
            uint8(outcome),
            uint8(PoolPlayPredictionMarket.PredictionOutcome.PENDING)
        );
    }

    function testFail_PlacePrediction_InactiveMarket() public {
        uint256 marketId = createTestMarket();
        vm.prank(owner);
        market.updateMarket(marketId, false);

        placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            5 ether
        );
    }

    function testFail_PlacePrediction_BetTooLow() public {
        uint256 marketId = createTestMarket();
        placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            0.5 ether // Less than minBetAmount
        );
    }

    // ===== Market Settlement Tests =====
    function test_SettleMarket_WithWinners() public {
        uint256 marketId = createTestMarket();

        // Place predictions
        uint256 pred1 = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            5 ether
        );

        uint256 pred2 = placePrediction(
            marketId,
            user2,
            PoolPlayPredictionMarket.ComparisonType.LESS_THAN,
            200 ether,
            0,
            5 ether
        );

        // Set TVL value in hook
        hook.setPoolTVL(poolId, 150 ether);

        // Fast forward to validation time
        vm.warp(block.timestamp + 1 days + 1);

        // Settle market
        market.settleMarket(marketId);

        // Check predictions
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            PoolPlayPredictionMarket.PredictionOutcome outcome1,
            ,
            ,

        ) = market.predictions(pred1);
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            PoolPlayPredictionMarket.PredictionOutcome outcome2,
            ,
            ,

        ) = market.predictions(pred2);

        assertEq(
            uint8(outcome1),
            uint8(PoolPlayPredictionMarket.PredictionOutcome.WON)
        );
        assertEq(
            uint8(outcome2),
            uint8(PoolPlayPredictionMarket.PredictionOutcome.WON)
        );
    }

    function test_SettleMarket_WithLosers() public {
        uint256 marketId = createTestMarket();

        // Place predictions
        uint256 pred1 = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            200 ether,
            0,
            5 ether
        );

        // Set TVL value in hook
        hook.setPoolTVL(poolId, 150 ether);

        // Fast forward to validation time
        vm.warp(block.timestamp + 1 days + 1);

        // Settle market
        market.settleMarket(marketId);

        // Check predictions
        (
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            ,
            PoolPlayPredictionMarket.PredictionOutcome outcome,
            ,
            ,

        ) = market.predictions(pred1);
        assertEq(
            uint8(outcome),
            uint8(PoolPlayPredictionMarket.PredictionOutcome.LOST)
        );
    }

    // ===== Withdrawal Tests =====
    function test_WithdrawWinnings() public {
        uint256 marketId = createTestMarket();
        uint256 betAmount = 5 ether;

        // Place winning prediction
        uint256 predId = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            betAmount
        );

        // Set TVL value and settle
        hook.setPoolTVL(poolId, 150 ether);
        vm.warp(block.timestamp + 1 days + 1);
        market.settleMarket(marketId);

        // Get initial balance
        uint256 initialBalance = bettingToken.balanceOf(user1);

        // Withdraw winnings
        vm.prank(user1);
        market.withdrawWinnings(predId);

        // Check balance increased
        uint256 finalBalance = bettingToken.balanceOf(user1);
        assertTrue(finalBalance > initialBalance);
    }

    function testFail_WithdrawWinnings_NotWinner() public {
        uint256 marketId = createTestMarket();

        // Place losing prediction
        uint256 predId = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            200 ether,
            0,
            5 ether
        );

        // Set TVL value and settle
        hook.setPoolTVL(poolId, 150 ether);
        vm.warp(block.timestamp + 1 days + 1);
        market.settleMarket(marketId);

        // Try to withdraw
        vm.prank(user1);
        market.withdrawWinnings(predId);
    }

    // ===== Admin Function Tests =====
    function test_WithdrawPlatformFees() public {
        uint256 marketId = createTestMarket();

        // Place some predictions to generate fees
        placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            10 ether
        );

        uint256 fees = market.totalPlatformFees();
        assertTrue(fees > 0);

        uint256 initialBalance = bettingToken.balanceOf(owner);

        vm.prank(owner);
        market.withdrawPlatformFees(fees);

        assertEq(market.totalPlatformFees(), 0);
        assertEq(bettingToken.balanceOf(owner), initialBalance + fees);
    }

    function testFail_WithdrawPlatformFees_NonOwner() public {
        vm.prank(user1);
        market.withdrawPlatformFees(1 ether);
    }

    function test_UpdatePoolPlayHook() public {
        address newHook = makeAddr("newHook");

        vm.prank(owner);
        market.updatePoolPlayHook(newHook);

        assertEq(address(market.poolPlayHook()), newHook);
    }

    function testFail_UpdatePoolPlayHook_NonOwner() public {
        address newHook = makeAddr("newHook");

        vm.prank(user1);
        market.updatePoolPlayHook(newHook);
    }

    // ===== View Function Tests =====
    function test_GetUserPredictions() public {
        uint256 marketId = createTestMarket();

        uint256 pred1 = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            5 ether
        );

        uint256[] memory predictions = market.getUserPredictions(user1);
        assertEq(predictions.length, 1);
        assertEq(predictions[0], pred1);
    }

    function test_GetMarketPredictions() public {
        uint256 marketId = createTestMarket();

        uint256 pred1 = placePrediction(
            marketId,
            user1,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            5 ether
        );

        uint256[] memory predictions = market.getMarketPredictions(marketId);
        assertEq(predictions.length, 1);
        assertEq(predictions[0], pred1);
    }

    function test_GetCurrentValue() public {
        uint256 expectedValue = 150 ether;
        hook.setPoolTVL(poolId, expectedValue);

        uint256 value = market.getCurrentValue(
            poolId,
            PoolPlayPredictionMarket.PredictionType.TVL
        );

        assertEq(value, expectedValue);
    }
}
