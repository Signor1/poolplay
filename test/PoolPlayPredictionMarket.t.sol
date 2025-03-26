// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import {Test} from "forge-std/Test.sol";
// import {PoolPlayPredictionMarket} from "../src/PredictionMarket.sol";
// import {PoolPlayHook} from "../src/PoolPlayHook.sol";
// import {PoolPlayRouter} from "../src/PoolPlayRouter.sol";
// import {MockERC20} from "./mocks/MockERC20.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
// import {PoolKey} from "v4-core/types/PoolKey.sol";
// import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
// import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
// import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
// import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
// import {AggregatorV3Interface} from "chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// contract PredictionMarketTest is Test, Deployers {
//     using PoolIdLibrary for PoolKey;
//     using CurrencyLibrary for Currency;

//     PoolPlayPredictionMarket public market;
//     PoolPlayHook public hook;
//     PoolPlayRouter public router;
//     IPoolManager public poolManager;
//     MockERC20 public token0;
//     MockERC20 public token1;
//     MockERC20 public bettingToken;
//     PoolKey public poolKey;
//     PoolId public poolId;

//     address public owner = makeAddr("owner");
//     address public user1 = makeAddr("user1");
//     address public user2 = makeAddr("user2");

//     event MarketCreated(
//         uint256 indexed marketId,
//         string title,
//         PoolPlayPredictionMarket.PredictionType predictionType
//     );
//     event PredictionPlaced(
//         uint256 indexed predictionId,
//         uint256 indexed marketId,
//         address user,
//         uint256 betAmount
//     );
//     event PredictionSettled(
//         uint256 indexed predictionId,
//         PoolPlayPredictionMarket.PredictionOutcome outcome,
//         uint256 potentialPayout
//     );
//     event MarketSettled(
//         uint256 indexed marketId,
//         uint256 actualValue,
//         uint256 winnerCount
//     );

//     function setUp() public {
//         vm.startPrank(owner);

//         // Deploy Uniswap V4 PoolManager
//         deployFreshManager();
//         poolManager = IPoolManager(manager);

//         // Deploy tokens
//         token0 = new MockERC20("Token0", "TKN0", 18);
//         token1 = new MockERC20("Token1", "TKN1", 18);
//         bettingToken = new MockERC20("Betting Token", "BET", 18);

//         // Deploy Hook and Router
//         hook = new PoolPlayHook(poolManager, address(router), address(0x456)); // lotteryPool stubbed
//         router = new PoolPlayRouter(address(poolManager), address(hook));

//         // Initialize pool
//         (key, ) = initPool(
//             Currency.wrap(address(token0)),
//             Currency.wrap(address(token1)),
//             hook,
//             3000,
//             60,
//             SQRT_PRICE_1_1
//         );

//         poolId = key.toId();
//         poolKey = key;

//         // Initialize pool in hook
//         hook.initializePool(poolId, 100, 1 days, 1);

//         // Deploy Prediction Market
//         market = new PoolPlayPredictionMarket(
//             address(hook),
//             address(bettingToken)
//         );

//         // Mint tokens
//         token0.mint(user1, 1000 ether);
//         token1.mint(user1, 1000 ether);
//         bettingToken.mint(user1, 1000 ether);
//         bettingToken.mint(user2, 1000 ether);

//         // Set mock Chainlink feeds
//         MockPriceFeed feed0 = new MockPriceFeed(2000e8); // 2000 USD per token0
//         MockPriceFeed feed1 = new MockPriceFeed(1e8); // 1 USD per token1
//         hook.setTokenFeed(address(token0), address(feed0));
//         hook.setTokenFeed(address(token1), address(feed1));

//         vm.stopPrank();

//         // Approvals
//         vm.prank(user1);
//         bettingToken.approve(address(market), type(uint256).max);
//         vm.prank(user2);
//         bettingToken.approve(address(market), type(uint256).max);
//         vm.prank(user1);
//         token0.approve(address(router), type(uint256).max);
//         vm.prank(user1);
//         token1.approve(address(router), type(uint256).max);
//     }

//     function test_CreateMarket() public {
//         vm.expectEmit(true, false, false, true);
//         emit MarketCreated(
//             1,
//             "Test Market",
//             PoolPlayPredictionMarket.PredictionType.TVL
//         );

//         vm.prank(owner);
//         market.createMarket(
//             "Test Market",
//             "Test Description",
//             PoolPlayPredictionMarket.PredictionType.TVL,
//             poolId,
//             block.timestamp + 1 days,
//             1 ether,
//             100 ether,
//             50
//         );

//         PoolPlayPredictionMarket.Market memory m = market.getMarket(1);

//         assertEq(m.id, 1);
//         assertEq(m.title, "Test Market");
//         assertEq(m.description, "Test Description");
//         assertEq(m.isActive, true);
//         assertEq(m.platformFee, 50);
//         assertEq(m.creator, address(this));
//     }

//     function test_PlacePrediction() public {
//         vm.prank(owner);

//         uint256 marketId = market.nextMarketId();

//         market.createMarket(
//             "Test Market",
//             "Test Description",
//             PoolPlayPredictionMarket.PredictionType.TVL,
//             poolId,
//             block.timestamp + 1 days,
//             1 ether,
//             100 ether,
//             50
//         );

//         vm.expectEmit(true, true, false, true);
//         emit PredictionPlaced(1, marketId, user1, 5 ether);

//         vm.prank(user1);
//         market.placePrediction(
//             marketId,
//             PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
//             100 ether,
//             0,
//             5 ether
//         );

//         (
//             ,
//             address user,
//             ,
//             ,
//             ,
//             ,
//             uint256 betAmount,
//             ,
//             ,
//             PoolPlayPredictionMarket.PredictionOutcome outcome,
//             ,
//             ,

//         ) = market.predictions(1);
//         assertEq(user, user1);
//         assertEq(betAmount, 5 ether);
//         assertEq(
//             uint8(outcome),
//             uint8(PoolPlayPredictionMarket.PredictionOutcome.PENDING)
//         );
//     }

//     function test_SettleMarket_WithWinners() public {
//         vm.prank(owner);

//         uint256 marketId = market.nextMarketId();

//         market.createMarket(
//             "Test Market",
//             "Test Description",
//             PoolPlayPredictionMarket.PredictionType.TVL,
//             poolId,
//             block.timestamp + 1 days,
//             1 ether,
//             100 ether,
//             50
//         );

//         // Place predictions
//         vm.prank(user1);

//         uint256 pred1 = market.nextPredictionId();

//         market.placePrediction(
//             marketId,
//             PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
//             100 ether,
//             0,
//             5 ether
//         );

//         vm.prank(user2);

//         market.placePrediction(
//             marketId,
//             PoolPlayPredictionMarket.ComparisonType.LESS_THAN,
//             300 ether,
//             0,
//             5 ether
//         );

//         uint256 pred2 = market.nextPredictionId();

//         // Add liquidity to affect TVL
//         vm.startPrank(user1);
//         poolManager.modifyLiquidity(
//             poolKey,
//             IPoolManager.ModifyLiquidityParams(0, 0, 100 ether, 0),
//             ZERO_BYTES
//         );
//         vm.stopPrank();

//         vm.warp(block.timestamp + 1 days + 1);
//         vm.prank(owner);
//         market.settleMarket(marketId);

//         (
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             PoolPlayPredictionMarket.PredictionOutcome outcome1,
//             ,
//             ,

//         ) = market.predictions(pred1);
//         (
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             ,
//             PoolPlayPredictionMarket.PredictionOutcome outcome2,
//             ,
//             ,

//         ) = market.predictions(pred2);
//         assertEq(
//             uint8(outcome1),
//             uint8(PoolPlayPredictionMarket.PredictionOutcome.WON)
//         );
//         assertEq(
//             uint8(outcome2),
//             uint8(PoolPlayPredictionMarket.PredictionOutcome.WON)
//         );
//     }

//     function test_WithdrawWinnings() public {
//         vm.prank(owner);
//         uint256 marketId = market.nextMarketId();

//         market.createMarket(
//             "Test Market",
//             "Test Description",
//             PoolPlayPredictionMarket.PredictionType.TVL,
//             poolId,
//             block.timestamp + 1 days,
//             1 ether,
//             100 ether,
//             50
//         );

//         vm.prank(user1);

//         uint256 predId = market.nextPredictionId();

//         market.placePrediction(
//             marketId,
//             PoolPlayPredictionMarket.ComparisonType.GREATER_THAN,
//             100 ether,
//             0,
//             5 ether
//         );

//         vm.startPrank(user1);
//         poolManager.modifyLiquidity(
//             poolKey,
//             IPoolManager.ModifyLiquidityParams(0, 0, 100 ether, 0),
//             ZERO_BYTES
//         );
//         vm.stopPrank();

//         vm.warp(block.timestamp + 1 days + 1);
//         vm.prank(owner);
//         market.settleMarket(marketId);

//         uint256 initialBalance = bettingToken.balanceOf(user1);
//         vm.prank(user1);
//         market.withdrawWinnings(predId);
//         assertGt(bettingToken.balanceOf(user1), initialBalance);
//     }
// }

// contract MockPriceFeed is AggregatorV3Interface {
//     int256 public price;
//     uint8 public constant DECIMALS = 8;

//     constructor(int256 _price) {
//         price = _price;
//     }

//     function decimals() external pure override returns (uint8) {
//         return DECIMALS;
//     }

//     function description() external pure override returns (string memory) {
//         return "Mock Price Feed";
//     }

//     function version() external pure override returns (uint256) {
//         return 1;
//     }

//     function getRoundData(
//         uint80
//     )
//         external
//         view
//         override
//         returns (
//             uint80 roundId,
//             int256 answer,
//             uint256 startedAt,
//             uint256 updatedAt,
//             uint80 answeredInRound
//         )
//     {
//         return (1, price, block.timestamp, block.timestamp, 1);
//     }

//     function latestRoundData()
//         external
//         view
//         override
//         returns (
//             uint80 roundId,
//             int256 answer,
//             uint256 startedAt,
//             uint256 updatedAt,
//             uint80 answeredInRound
//         )
//     {
//         return (1, price, block.timestamp, block.timestamp, 1);
//     }
// }
