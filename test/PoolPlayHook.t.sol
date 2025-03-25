// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import {Test} from "forge-std/Test.sol";
// import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
// import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
// import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
// import {PoolManager} from "v4-core/PoolManager.sol";
// import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
// import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
// import {Hooks} from "v4-core/libraries/Hooks.sol";
// import {TickMath} from "v4-core/libraries/TickMath.sol";
// import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
// import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
// import {PoolKey} from "v4-core/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
// import {PoolPlayHook} from "../src/PoolPlayHook.sol";
// import {LotteryPoolFactory} from "../src/LotteryPoolFactory.sol";
// import {LotteryPool} from "../src/LotteryPool.sol";
// import {PredictionMarketFactory} from "../src/PredictionMarketFactory.sol";
// import {PredictionMarket} from "../src/PredictionMarket.sol";
// import {VRFCoordinatorV2Mock} from "chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
// import {MockV3Aggregator} from "chainlink-brownie-contracts/contracts/src/v0.8/tests/MockV3Aggregator.sol";
// import "forge-std/console.sol";

// contract PoolPlayHookTest is Test, Deployers {
//     using CurrencyLibrary for Currency;
//     using PoolIdLibrary for PoolKey;

//     PoolManager localManager;
//     PoolPlayHook hook;
//     LotteryPoolFactory lotteryFactory;
//     LotteryPool lotteryPool;
//     PredictionMarketFactory predictionFactory;
//     PredictionMarket predictionMarket;
//     VRFCoordinatorV2Mock vrfCoordinator;
//     MockERC20 token0;
//     MockERC20 token1;
//     MockV3Aggregator mockFeed0;
//     MockV3Aggregator mockFeed1;

//     Currency localCurrency0;
//     Currency localCurrency1;
//     PoolKey localKey;
//     PoolId localPoolId;

//     function setUp() public {
//         // Deploy PoolManager and routers
//         deployFreshManagerAndRouters();

//         // Deploy mock tokens
//         token0 = new MockERC20("Token0", "TKN0", 18);
//         token1 = new MockERC20("Token1", "TKN1", 18);
//         localCurrency0 = Currency.wrap(address(token0));
//         localCurrency1 = Currency.wrap(address(token1));

//         // Mint tokens to this contract for testing
//         token0.mint(address(this), 1000 ether);
//         token1.mint(address(this), 1000 ether);

//         // Deploy VRFCoordinator mock for LotteryPool
//         vrfCoordinator = new VRFCoordinatorV2Mock(0.1 ether, 1e9); // Base fee, gas price

//         // Deploy LotteryPool master contract
//         LotteryPool lotteryMaster = new LotteryPool(address(vrfCoordinator));

//         // Deploy LotteryPoolFactory
//         lotteryFactory = new LotteryPoolFactory(
//             localManager,
//             address(lotteryMaster)
//         );

//         // Deploy PredictionMarket master contract
//         PredictionMarket predictionMaster = new PredictionMarket();

//         // Deploy PredictionMarketFactory
//         predictionFactory = new PredictionMarketFactory(
//             address(hook),
//             address(predictionMaster)
//         );

//         // Set up hook permissions flags
//         uint160 flags = uint160(
//             Hooks.BEFORE_INITIALIZE_FLAG |
//                 Hooks.BEFORE_SWAP_FLAG |
//                 Hooks.AFTER_ADD_LIQUIDITY_FLAG |
//                 Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
//         );

//         // Deploy PoolPlayHook with the correct flags
//         deployCodeTo(
//             "PoolPlayHook.sol",
//             abi.encode(localManager, address(lotteryFactory)),
//             address(flags)
//         );
//         hook = PoolPlayHook(address(flags));

//         // Create a pool via factory
//         localKey = PoolKey({
//             currency0: currency0,
//             currency1: currency1,
//             fee: 3000, // 0.3% fee
//             tickSpacing: 60,
//             hooks: hook
//         });
//         address hookAddress = lotteryFactory.createPool(localKey, 50, 1 days); // 0.5% lottery fee, 1-day interval
//         hook = PoolPlayHook(hookAddress); // Update hook to the cloned instance
//         (address lotteryPoolAddress, , , ) = hook.poolConfigs(localKey.toId());
//         lotteryPool = LotteryPool(lotteryPoolAddress);

//         // Set up mock price feeds
//         mockFeed0 = new MockV3Aggregator(8, 1e6);
//         mockFeed0.updateAnswer(1 * 10 ** 8); // Token0 price is $1 with 8 decimal places
//         mockFeed1 = new MockV3Aggregator(8, 1e6);
//         mockFeed1.updateAnswer(1 * 10 ** 8); // Token1 price is $1 with 8 decimal places

//         // Set token feeds in PoolPlayHook
//         hook.setTokenFeed(address(token0), address(mockFeed0));
//         hook.setTokenFeed(address(token1), address(mockFeed1));

//         // Initialize pool
//         localManager.initialize(localKey, SQRT_PRICE_1_1);

//         // Add initial liquidity
//         uint256 token0ToAdd = 1 ether;
//         uint256 token1ToAdd = 1 ether;
//         modifyLiquidityRouter.modifyLiquidity(
//             localKey,
//             IPoolManager.ModifyLiquidityParams({
//                 tickLower: -60,
//                 tickUpper: 60,
//                 liquidityDelta: int256(

//                     uint256(
//                         LiquidityAmounts.getLiquidityForAmounts(
//                             SQRT_PRICE_1_1,
//                             TickMath.getSqrtPriceAtTick(-60),
//                             TickMath.getSqrtPriceAtTick(60),
//                             token0ToAdd,
//                             token1ToAdd
//                         )

//                     )
//                 ),
//                 salt: bytes32(0)
//             }),
//             ""
//         );

//         // Approve tokens for hook swaps
//         token0.approve(address(hook), type(uint256).max);
//         token1.approve(address(hook), type(uint256).max);

//         // Create a PredictionMarket for the pool
//         predictionMarket = PredictionMarket(
//             predictionFactory.createMarket(key, address(token0))
//         );

//         // Fund subscription for LotteryPool
//         uint64 subId = vrfCoordinator.createSubscription();
//         vrfCoordinator.fundSubscription(subId, 1 ether);
//         lotteryPool.setSubscriptionId(subId);
//     }

//     function test_lotteryFeeCollection() public {
//         uint256 initialBalance = token0.balanceOf(address(lotteryPool));
//         uint256 swapAmount = 0.1 ether;
//         uint256 expectedFee = (swapAmount * 50) / 10_000; // 0.5% fee

//         // Perform a swap
//         swapRouter.swap(
//             localKey,
//             IPoolManager.SwapParams({
//                 zeroForOne: true,
//                 amountSpecified: -int256(swapAmount),
//                 sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
//             }),
//             PoolSwapTest.TestSettings({
//                 takeClaims: false,
//                 settleUsingBurn: false
//             }),
//             ""
//         );

//         uint256 finalBalance = token0.balanceOf(address(lotteryPool));
//         assertEq(
//             finalBalance - initialBalance,
//             expectedFee,
//             "Lottery fee not collected correctly"
//         );
//     }

//     function test_getPoolTVL() public {
//         uint256 tvl = hook.getPoolTVL(key.toId());
//         // Initial TVL should be approximately 2 USD (1 token each worth $1)
//         assertApproxEqAbs(
//             tvl,
//             2 ether,
//             0.01 ether,
//             "TVL calculation incorrect"
//         );
//     }

//     function test_liquidityUpdate() public {
//         // Check initial participants

//         // (, , , , address[] memory participants) = lotteryPool.epochs(
//         //     lotteryPool.currentEpoch()
//         // );
//         // assertEq(participants.length, 1, "Initial participant not recorded");

//         // Add more liquidity
//         uint256 additionalToken0 = 0.5 ether;
//         uint256 additionalToken1 = 0.5 ether;
//         token0.mint(address(this), additionalToken0);
//         token1.mint(address(this), additionalToken1);
//         token0.approve(address(modifyLiquidityRouter), additionalToken0);
//         token1.approve(address(modifyLiquidityRouter), additionalToken1);

//         modifyLiquidityRouter.modifyLiquidity(
//             localKey,
//             IPoolManager.ModifyLiquidityParams({
//                 tickLower: -120,
//                 tickUpper: 120,
//                 liquidityDelta: int256(

//                     uint256(
//                         LiquidityAmounts.getLiquidityForAmounts(
//                             SQRT_PRICE_1_1,
//                             TickMath.getSqrtPriceAtTick(-120),
//                             TickMath.getSqrtPriceAtTick(120),
//                             additionalToken0,
//                             additionalToken1
//                         )
//                     )
//                 ),
//                 salt: bytes32(0)
//             }),
//             ""
//         );

//         // (, , participants) = lotteryPool.epochs(lotteryPool.currentEpoch());
//         // assertEq(
//         //     participants.length,
//         //     1,
//         //     "Multiple participants should not be added for same address"
//         // );

//     }

//     function test_epochTransition() public {
//         // Warp time to trigger epoch end
//         vm.warp(block.timestamp + 1 days + 1);

//         // Trigger updateLiquidity to start new epoch
//         vm.prank(address(manager));

//         hook.afterAddLiquidity(
//             address(this),
//             localKey,
//             IPoolManager.ModifyLiquidityParams(0, 0, 0, bytes32(0)),

//             BalanceDeltaLibrary.ZERO_DELTA,
//             BalanceDeltaLibrary.ZERO_DELTA,
//             ""
//         );

//         assertEq(lotteryPool.currentEpoch(), 2, "Epoch did not transition");
//     }

//     function test_lotteryWinnerSelection() public {
//         // Perform swaps to accumulate fees
//         uint256 swapAmount = 0.1 ether;
//         for (uint256 i = 0; i < 10; i++) {
//             swapRouter.swap(
//                 localKey,
//                 IPoolManager.SwapParams({
//                     zeroForOne: true,
//                     amountSpecified: -int256(swapAmount),
//                     sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
//                 }),
//                 PoolSwapTest.TestSettings({
//                     takeClaims: false,
//                     settleUsingBurn: false
//                 }),
//                 ""
//             );
//         }

//         // Warp time to trigger epoch end
//         vm.warp(block.timestamp + 1 days + 1);

//         // Trigger updateLiquidity to request new winner
//         vm.prank(address(manager));

//         hook.afterAddLiquidity(
//             address(this),
//             localKey,
//             IPoolManager.ModifyLiquidityParams(0, 0, 0, bytes32(0));

//             BalanceDeltaLibrary.ZERO_DELTA,
//             BalanceDeltaLibrary.ZERO_DELTA,
//             ""
//         );

//         // Get the request ID from the last epoch
//         uint256 lastEpoch = lotteryPool.currentEpoch() - 1;

//         uint256 requestId = lotteryPool.epochToRequestID(lastEpoch);

//         // Simulate VRF fulfillment with mock randomness
//         uint256[] memory randomWords = new uint256[](1);
//         randomWords[0] = 42; // Mock random number
//         vm.prank(address(vrfCoordinator));

//         // lotteryPool.fulfillRandomWords(uint256(requestId), randomWords);

//         // Check if winner was selected and prize was distributed
//         (, , uint256 totalFees) = lotteryPool.epochs(lastEpoch);
//         assertGt(totalFees, 0, "Fees should be accumulated");
//         // assertGt(participants.length, 0, "Should have participants");

//         // Note: Winner selection is probabilistic, so we can't assert a specific winner, but ensure event was emitted
//     }

//     function test_placeAndSettleBet() public {
//         // Initial TVL is 2 USD
//         uint256 initialTVL = hook.getPoolTVL(localKey.toId());
//         assertEq(initialTVL, 2 ether);

//         // Place a bet that TVL will be above 3 USD in 1 day
//         uint256 targetTVL = 3 ether;
//         uint256 betAmount = 1 ether;
//         uint40 duration = 1 days;

//         // Call placeBet
//         predictionMarket.placeBet(localKey, targetTVL, betAmount, duration);

//         // Get the bet ID

//         PredictionMarket.Bet[] memory bets = predictionMarket.getBets();
//         uint256 betId = bets.length - 1;

//         // Now, add more liquidity to make TVL exceed 3 USD
//         uint256 additionalToken0 = 2 ether;
//         uint256 additionalToken1 = 2 ether;
//         token0.mint(address(this), additionalToken0);
//         token1.mint(address(this), additionalToken1);
//         token0.approve(address(modifyLiquidityRouter), additionalToken0);
//         token1.approve(address(modifyLiquidityRouter), additionalToken1);

//         modifyLiquidityRouter.modifyLiquidity(
//             localKey,
//             IPoolManager.ModifyLiquidityParams({
//                 tickLower: -60,
//                 tickUpper: 60,
//                 liquidityDelta: int256(

//                     uint256(
//                         LiquidityAmounts.getLiquidityForAmounts(
//                             SQRT_PRICE_1_1,
//                             TickMath.getSqrtPriceAtTick(-60),
//                             TickMath.getSqrtPriceAtTick(60),
//                             additionalToken0,
//                             additionalToken1
//                         )

//                     )
//                 ),
//                 salt: bytes32(0)
//             }),
//             ""
//         );

//         // Now, TVL should be initial 2 + additional value
//         // Each token's balance is now 3 ether, each worth $1, so TVL should be 6 USD
//         uint256 newTVL = hook.getPoolTVL(localKey.toId());
//         assertEq(newTVL, 6 ether);

//         // Warp time to settle time
//         uint40 settleTime = uint40(block.timestamp + duration);
//         vm.warp(settleTime);

//         // Settle the bet
//         predictionMarket.settleBet(betId);

//         // Check if the bet is won

//         PredictionMarket.Bet memory bet = predictionMarket.getBet(betId);
//         require(bet.resolved && bet.won, "Bet should be won");

//         // Check if reward was transferred
//         // Assuming reward is betAmount * 2
//         uint256 reward = betAmount * 2;
//         assertEq(token0.balanceOf(address(this)), reward);
//     }
// }
