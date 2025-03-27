// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolPlayPredictionMarket} from "../src/PredictionMarket.sol";
import {PoolPlayHook} from "../src/PoolPlayHook.sol";
import {PoolPlayRouter} from "../src/PoolPlayRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPoolPlayHook} from "./mocks/MockPoolPlayHook.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PredictionMarketTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    MockPoolPlayHook public mockHook;
    PoolPlayPredictionMarket public market;
    PoolPlayHook public hook;
    PoolPlayRouter public router;
    IPoolManager public poolManager;
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public bettingToken;
    PoolKey public poolKey;
    PoolId public poolId;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    event MarketCreated(uint256 indexed marketId, string title, PoolPlayPredictionMarket.PredictionType predictionType);
    event PredictionPlaced(uint256 indexed predictionId, uint256 indexed marketId, address user, uint256 betAmount);
    event PredictionSettled(
        uint256 indexed predictionId, PoolPlayPredictionMarket.PredictionOutcome outcome, uint256 potentialPayout
    );
    event MarketSettled(uint256 indexed marketId, uint256 actualValue, uint256 winnerCount);

    function setUp() public {
        deployFreshManagerAndRouters();
        poolManager = IPoolManager(manager);

        token0 = new MockERC20("Token0", "TKN0", 18);
        token1 = new MockERC20("Token1", "TKN1", 18);
        bettingToken = new MockERC20("Betting Token", "BET", 18);

        // Deploy PoolPlayRouter first (will be updated as allowedRouter in hook)
        router = new PoolPlayRouter(address(poolManager), address(0)); // Hook address will be set later

        // Deploy PoolPlayHook with precomputed address for hook permissions
        uint160 flags = uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        address hookAddress = address(flags);
        deployCodeTo("PoolPlayHook.sol", abi.encode(poolManager, address(router), address(0)), hookAddress); // lotteryPool stubbed
        hook = PoolPlayHook(payable(hookAddress));

        mockHook = new MockPoolPlayHook();
        // Update router with hook address
        router = new PoolPlayRouter(address(poolManager), address(hook));

        // Initialize Uniswap V4 pool
        (poolKey,) =
            initPool(Currency.wrap(address(token0)), Currency.wrap(address(token1)), hook, 3000, 60, SQRT_PRICE_1_1);
        poolId = poolKey.toId();

        // Initialize pool in hook (owner is address(this), no prank needed)
        hook.initializePool(poolId, 100, 1 days, 1);

        // Deploy Prediction Market (owner is address(this) via Ownable)
        market = new PoolPlayPredictionMarket(address(mockHook), address(bettingToken));

        // Mint tokens to test contract and users
        token0.mint(address(this), 1000 ether);
        token1.mint(address(this), 1000 ether);
        bettingToken.mint(user1, 1000 ether);
        bettingToken.mint(user2, 1000 ether);

        // Add liquidity from address(this) (owner)
        token0.approve(address(modifyLiquidityRouter), type(uint256).max);
        token1.approve(address(modifyLiquidityRouter), type(uint256).max);
        modifyLiquidityRouter.modifyLiquidity(
            poolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 100 ether, 0), ZERO_BYTES
        );

        // User approvals for betting
        vm.prank(user1);
        bettingToken.approve(address(market), type(uint256).max);
        vm.prank(user2);
        bettingToken.approve(address(market), type(uint256).max);
    }

    // Helper function to create a market
    function createTestMarket() public returns (uint256) {
        vm.startPrank(owner);
        uint256 marketId = market.nextMarketId();

        market.createMarket(
            "Test Market",
            poolId,
            PoolPlayPredictionMarket.PredictionType.TVL,
            block.timestamp + 1 days,
            1 ether,
            100 ether
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

        market.placePrediction(marketId, compType, targetValue, targetValue2, betAmount);

        vm.stopPrank();

        return predictionId;
    }

    function test_CreateMarket() public {
        uint256 marketId = market.nextMarketId();

        vm.expectEmit(true, false, false, true);
        emit MarketCreated(marketId, "Test Market", PoolPlayPredictionMarket.PredictionType.TVL);

        marketId = createTestMarket();

        PoolPlayPredictionMarket.Market memory m = market.getMarket(marketId);
        assertEq(m.title, "Test Market");
        assertEq(m.isActive, true);
        assertEq(m.platformFee, 50);
    }

    function test_PlacePrediction() public {
        vm.prank(owner);
        market.createMarket(
            "Test Market",
            poolId,
            PoolPlayPredictionMarket.PredictionType.TVL,
            block.timestamp + 1 days,
            1 ether,
            100 ether
        );

        vm.expectEmit(true, true, false, true);
        emit PredictionPlaced(1, 1, user1, 5 ether);

        vm.prank(user1);
        market.placePrediction(1, PoolPlayPredictionMarket.ComparisonType.GREATER_THAN, 100 ether, 0, 5 ether);

        PoolPlayPredictionMarket.Prediction memory m = market.getPrediction(1);

        assertEq(m.user, user1);
    }

    function test_RevertIf_PlacePrediction_BetTooLow() public {
        uint256 marketId = createTestMarket();

        vm.prank(user1);
        vm.expectRevert("Invalid bet amount");
        market.placePrediction(
            marketId,
            PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
            100 ether,
            0,
            0.5 ether // Less than minBetAmount of 1 ether
        );
    }

    function test_SettleMarket_WithWinners() public {
        uint256 marketId = createTestMarket();

        vm.prank(user1);
        market.placePrediction(marketId, PoolPlayPredictionMarket.ComparisonType.GREATER_THAN, 100 ether, 0, 5 ether);

        vm.prank(user2);
        market.placePrediction(marketId, PoolPlayPredictionMarket.ComparisonType.LESS_THAN, 200 ether, 0, 5 ether);

        // Set TVL value in hook
        mockHook.setPoolTVL(poolId, 150 ether);

        vm.warp(block.timestamp + 1 days + 1);

        market.settleMarket(marketId);

        (,,,,,, PoolPlayPredictionMarket.PredictionOutcome outcome1,,) = market.predictions(1);
        (,,,,,, PoolPlayPredictionMarket.PredictionOutcome outcome2,,) = market.predictions(2);
        assertEq(uint8(outcome1), uint8(PoolPlayPredictionMarket.PredictionOutcome.WON));
        assertEq(uint8(outcome2), uint8(PoolPlayPredictionMarket.PredictionOutcome.WON));
    }

    function test_WithdrawWinnings() public {
        uint256 marketId = createTestMarket();
        uint256 betAmount = 5 ether;

        // Place winning prediction
        uint256 predId = placePrediction(
            marketId, user1, PoolPlayPredictionMarket.ComparisonType.GREATER_THAN, 100 ether, 0, betAmount
        );

        // Set TVL value and settle
        mockHook.setPoolTVL(poolId, 150 ether);
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

    function test_RevertIf_WithdrawWinnings_NotWinner() public {
        uint256 marketId = createTestMarket();

        // Place losing prediction
        uint256 predId = placePrediction(
            marketId, user1, PoolPlayPredictionMarket.ComparisonType.GREATER_THAN, 200 ether, 0, 5 ether
        );

        // Set TVL value and settle
        mockHook.setPoolTVL(poolId, 150 ether);
        vm.warp(block.timestamp + 1 days + 1);
        market.settleMarket(marketId);

        // Try to withdraw
        vm.prank(user1);
        vm.expectRevert("Not a winner");
        market.withdrawWinnings(predId);
    }

    // ===== Admin Function Tests =====
    function test_WithdrawPlatformFees() public {
        uint256 marketId = createTestMarket();

        // Place some predictions to generate fees
        placePrediction(marketId, user1, PoolPlayPredictionMarket.ComparisonType.GREATER_THAN, 100 ether, 0, 10 ether);

        uint256 fees = market.totalPlatformFees();
        assertTrue(fees > 0);

        uint256 initialBalance = bettingToken.balanceOf(address(this));

        vm.prank(address(this));
        market.withdrawPlatformFees(fees);

        assertEq(market.totalPlatformFees(), 0);
        assertEq(bettingToken.balanceOf(address(this)), initialBalance + fees);
    }

    function test_RevertIf_WithdrawPlatformFees_NonOwner() public {
        bytes memory expectedRevert =
            abi.encodeWithSelector(bytes4(keccak256("OwnableUnauthorizedAccount(address)")), user1);
        vm.prank(user1);
        vm.expectRevert(expectedRevert);
        market.withdrawPlatformFees(1 ether);
    }

    function test_GetCurrentValue() public {
        uint256 expectedValue = 150 ether;
        mockHook.setPoolTVL(poolId, expectedValue);

        uint256 value = market.getCurrentValue(poolId, PoolPlayPredictionMarket.PredictionType.TVL);

        assertEq(value, expectedValue);
    }
}
